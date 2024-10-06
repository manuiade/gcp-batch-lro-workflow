# GCP Batch for Long Running Operations using Cloud Workflow

This sample demo repository sets up a Cloud Workflow scheduler which performs the following for running a long running operation (LRO):

- Create a batch job (using a prime number generator sample lro)
- Polling check the Job to retrieve its status
- Delete batch job
- Return success/non-success Job status

![](/architecture.png)

Read the articles <link> to more details on the conceptual overview on the proposed solution.

## Env vars

```bash
PROJECT_ID=<PROJECT_ID>

VPC=lro-vpc
SUBNET=lro-subnet
REGION=europe-west1
SUBNET_RANGE=10.10.0.0/24
WORKFLOW_SA=lro-workflow
BATCH_SA=lro-vm

AR_REPO=primegen
WORKFLOW_NAME=primegen

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

gcloud config set project $PROJECT_ID
```

## Activate APIs

```bash
gcloud services enable artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  compute.googleapis.com \
  workflowexecutions.googleapis.com \
  batch.googleapis.com \
  workflows.googleapis.com
```


## Requirements

### VPC and subnet

```bash
gcloud compute networks create $VPC \
	--project=$PROJECT_ID \
	--subnet-mode=custom

gcloud compute networks subnets create $SUBNET \
	--project=$PROJECT_ID \
	--range=$SUBNET_RANGE \
	--network=$VPC \
	--region=$REGION \
	--enable-private-ip-google-access
```

### Test image locally

```bash
docker build -t primegen primegen/
docker run --rm --name primegen primegen 12345
```

### Create Artifact Registry repo and push image

```bash
gcloud artifacts repositories create $AR_REPO \
  --repository-format=docker \
  --location=$REGION

gcloud builds submit \
  -t $REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO/primegen:v1 primegen/
```

### Service account for Batch and related permissions

```bash
gcloud iam service-accounts create $BATCH_SA

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/logging.logWriter

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/batch.agentReporter

gcloud artifacts repositories add-iam-policy-binding $AR_REPO \
  --member=serviceAccount:${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/artifactregistry.reader \
  --location $REGION
```


### Service account for Workflow and related permissions

```bash
gcloud iam service-accounts create $WORKFLOW_SA

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/batch.jobsEditor

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/logging.logWriter

gcloud iam service-accounts add-iam-policy-binding \
  ${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountUser
```



### Deploy and start Workflow

```bash
gcloud workflows deploy $WORKFLOW_NAME \
  --source workflow-lro.yaml \
  --service-account=${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --location=$REGION
```

### Test call

```bash
gcloud workflows execute $WORKFLOW_NAME --location $REGION --data \
"{
  \"batchServiceAccount\": \"${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com\",
  \"region\": \"$REGION\",
  \"network\" : \"$VPC\",
  \"subnetwork\": \"$SUBNET\",
  \"machineType\": \"e2-medium\",
  \"diskType\": \"pd-balanced\",
  \"diskSizeGb\": \"30\",
  \"imageUri\" : \"$REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO/primegen:v1\",
  \"jobName\" : \"test-lro\",
  \"PRIME_NUMBER_LIMIT\": \"100000\"
}"
```

### Test call with polling check using Batch Connector and notification to GGCHAT

```bash
WEBHOOK_URL=<WEBHOOK_URL>

gcloud workflows deploy $WORKFLOW_NAME \
  --source workflow-lro-webhook-notification.yaml \
  --service-account=${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --location=$REGION

gcloud workflows execute $WORKFLOW_NAME --location $REGION --data \
"{
  \"batchServiceAccount\": \"${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com\",
  \"region\": \"$REGION\",
  \"network\" : \"$VPC\",
  \"subnetwork\": \"$SUBNET\",
  \"machineType\": \"e2-medium\",
  \"diskType\": \"pd-balanced\",
  \"diskSizeGb\": \"30\",
  \"imageUri\" : \"$REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO/primegen:v1\",
  \"jobName\" : \"test-lro\",
  \"PRIME_NUMBER_LIMIT\": \"10000\",
  \"webhookUrl\": \"$WEBHOOK_URL\"
}"
```

## Cleanup

```bash 
gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/batch.jobsEditor

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/logging.logWriter

gcloud iam service-accounts remove-iam-policy-binding \
  ${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountUser

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/logging.logWriter

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/batch.agentReporter

gcloud artifacts repositories remove-iam-policy-binding $AR_REPO \
  --member=serviceAccount:${BATCH_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/artifactregistry.reader \
  --location $REGION

gcloud iam service-accounts delete $WORKFLOW_SA@${PROJECT_ID}.iam.gserviceaccount.com --quiet

gcloud iam service-accounts delete $BATCH_SA@${PROJECT_ID}.iam.gserviceaccount.com --quiet

gcloud workflows delete $WORKFLOW_NAME --location $REGION --quiet

gcloud artifacts repositories delete $AR_REPO --location $REGION --quiet

gcloud compute networks subnets delete $SUBNET --region $REGION --quiet

gcloud compute networks delete $VPC --quiet
```