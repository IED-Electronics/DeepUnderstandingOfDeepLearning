.PHONY: create-sg create-instance forward-port help

# Include the configuration file
include instances.config

MY_IP=$$(curl -s ifconfig.me)

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help              Show this help message"
	@echo "  create-instance   Create a new instance"
	@echo "  forward-port      Forward port 8888 to 9999"
	@echo "  start-instance    Start the instance"
	@echo "  stop-instance     Stop the instance"
	@echo "  remove-instance   Terminate the instance and delete the security group"
	@echo "  install-requirements   Install the requirements.txt file in the instance"
	@echo "Before running any target, make sure to:"
	@echo "1. Modify the file 'instances.config.template' with your specific configurations."
	@echo "2. Rename 'instances.config.template' to 'instances.config'."

create-sg:
	@SG_ID=$$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$(SG_NAME)" "Name=vpc-id,Values=$(VPC_ID)" --query 'SecurityGroups[0].GroupId' --output text); \
	if [ "$$SG_ID" = "None" ] || [ -z "$$SG_ID" ]; then \
		echo "$(MY_IP)/32"; \
		SG_ID=$$(aws ec2 create-security-group \
			--group-name $(SG_NAME) \
			--description "Security group for notebooks" \
			--vpc-id $(VPC_ID) \
			--query 'GroupId' \
			--output text); \
		aws ec2 authorize-security-group-ingress \
			--group-id $$SG_ID \
			--protocol -1 \
			--cidr $(MY_IP)/32; \
		echo "Security group created $$SG_ID"; \
	else \
		echo "Security group already exists"; \
	fi;
	

create-instance: create-sg
	@SG_ID=$$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$(SG_NAME)" "Name=vpc-id,Values=$(VPC_ID)" --query 'SecurityGroups[0].GroupId' --output text); \
	sed 's/--NotebookApp.token="[^"]*"/--NotebookApp.token="$(JUPYTER_TOKEN)"/' user-data-instance.sh > user-data-instance.sh.tmp; \
	INSTANCE_ID=$$(aws ec2 run-instances \
		--subnet-id $(SUBNET_ID) \
		--image-id ami-08826d95c234de246 \
		--instance-type $(INSTANCE_TYPE) \
 		--security-group-ids $$SG_ID \
		--iam-instance-profile Name=AmazonSSMRoleForInstancesQuickSetup \
		--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=$(INSTANCE_NAME)}]' \
		--user-data file://user-data-instance.sh.tmp \
        --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":500}}]' \
        --query 'Instances[0].InstanceId' \
		--output text); \
	rm user-data-instance.sh.tmp; \
	echo "\nINSTANCE_ID=$$INSTANCE_ID" >> instances.config; \
	echo "Instance $$INSTANCE_ID created"; \
	echo "Please wait a little (5 mins) for the instance to be ready."; \
	echo "Then you can use the command 'make forward-port'"; \
	echo "Finally you will have to connect the python notebook to the kernel in the following url:"; \
	echo "http://localhost:9999/lab?token=$(JUPYTER_TOKEN)";

forward-port:
	aws ssm start-session --target $(INSTANCE_ID) --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{"portNumber":["8888"],"localPortNumber":["9999"]}'

start-instance:
	aws ec2 start-instances --instance-ids $(INSTANCE_ID); \
	echo "Instance $(INSTANCE_ID) started."; 
	echo "Please wait a little for the instance to be ready."; \
	echo "Then you can use the command 'make forward-port'"; \
	echo "Finally you will have to connect the python notebook to the kernel in the following url:"; \
	echo "http://localhost:9999/lab?token=$(JUPYTER_TOKEN)";

stop-instance:
	aws ec2 stop-instances --instance-ids $(INSTANCE_ID)
	@echo "Instance $(INSTANCE_ID) stopped."

restart-instance: stop-instance start-instance

destroy-sg:
	@SG_ID=$$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$(SG_NAME)" "Name=vpc-id,Values=$(VPC_ID)" --query 'SecurityGroups[0].GroupId' --output text); \
	aws ec2 delete-security-group --group-id $$SG_ID; \
	echo "Security group $(SG_ID) deleted.";

destroy-instance:
	@SG_ID=$$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$(SG_NAME)" "Name=vpc-id,Values=$(VPC_ID)" --query 'SecurityGroups[0].GroupId' --output text); \
	aws ec2 terminate-instances --instance-ids $(INSTANCE_ID); \
	while state=$$(aws ec2 describe-instances --instance-ids $(INSTANCE_ID) --query 'Reservations[0].Instances[0].State.Name' --output text); [ "$$state" != "terminated" ]; do \
		echo "Waiting for instance to terminate..."; \
		sleep 5; \
	done; \
	sed -i '/^INSTANCE_ID=$(INSTANCE_ID)/d' instances.config; \
	echo "Instance $(INSTANCE_ID) terminated";
	
remove-instance: destroy-instance destroy-sg

install-requirements:
	@echo "Installing requirements in groups of 10 packages"
	@REQUIREMENTS=$$(cat requirements.txt | tr '\n' ' '); \
	REQ_GROUPS=$$(echo $$REQUIREMENTS | tr ' ' '\n' | awk '{print} NR % 10 == 0 {print ""}' | tr '\n' ' '); \
	COMMANDS=$$(for group in $$REQ_GROUPS; do echo '/home/ubuntu/anaconda3/bin/python -m pip install' $$group '&&'; done); \
	COMMANDS=$$(echo $$COMMANDS | sed 's/&&$$//'); \
	aws ssm send-command --instance-ids "$(INSTANCE_ID)" --document-name "AWS-RunShellScript" --parameters commands="$$COMMANDS"

install-requirements-output:
	aws ssm get-command-invocation --command-id "744117aa-ce0a-4855-a2cd-df9cff97b60c" --instance-id "$(INSTANCE_ID)"