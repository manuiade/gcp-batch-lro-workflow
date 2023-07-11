# GCP Batch for Long Running Operations using Cloud Workflow

This sample demo repository sets up a Cloud Workflow scheduler which performs the following for running a long running operation:

- Create a callback endpoint
- Create a GCE batch job (using a prime number generator sample lro)
- Await for being called back by Batch
- Once finished the LRO the callback url is called to resume Workflow execution
- Delete batch job
- Return success/non-success

## Env vars

```
PROJECT_ID=<PROJECT_ID>

VPC=lro-vpc
SUBNET=lro-subnet
REGION=europe-west3
SUBNET_RANGE=10.10.0.0/24
WORKFLOW_SA=lro-workflow
GCE_SA=lro-vm

AR_REPO=primegen
WORKFLOW_NAME=primegen

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

gcloud config set project $PROJECT_ID
```

## Activate APIs
```
gcloud services enable artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  compute.googleapis.com \
  workflowexecutions.googleapis.com \
  workflows.googleapis.com
```


## Requirements

### VPC and subnet

```
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

### Service account (for Workflow and GCE Instance) and related permissions
```
gcloud iam service-accounts create $WORKFLOW_SA

gcloud iam service-accounts create $GCE_SA

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/compute.admin

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/batch.jobsEditor

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/logging.logWriter

gcloud iam service-accounts add-iam-policy-binding \
  ${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountUser



gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/workflows.invoker

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/logging.logWriter

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/artifactregistry.reader

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/batch.agentReporter
```

### Test image locally
```
docker build -t primegen primegen/
docker run --rm --name primegen primegen 42 0
```

### Create Artifact Registry repo and push image

```
gcloud artifacts repositories create $AR_REPO \
    --repository-format=docker \
    --location=$REGION

gcloud builds submit \
  -t $REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO/primegen:v1 primegen/
```

### Deploy and start Workflow

```
gcloud workflows deploy $WORKFLOW_NAME \
  --source workflow.yaml \
  --service-account=${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --location=$REGION
```


### Test call

```
gcloud workflows execute $WORKFLOW_NAME --location $REGION --data \
"{
  \"gceServiceAccount\": \"${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com\",
  \"instanceName\": \"backup-gcs\",
  \"machineType\": \"e2-medium\",
  \"region\": \"$REGION\",
  \"network\" : \"$VPC\",
  \"subnetwork\": \"$SUBNET\",
  \"jobName\" : \"test-lro\",
  \"imageUri\" : \"$REGION-docker.pkg.dev/$PROJECT_ID/$AR_REPO/primegen:v1\",
  \"primeNumberTarget\": \"4242\"
}"
```

## Cleanup

```
gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/compute.admin

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/batch.jobsEditor

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/logging.logWriter

gcloud iam service-accounts remove-iam-policy-binding \
  ${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --member=serviceAccount:${WORKFLOW_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountUser



gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/workflows.invoker

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/logging.logWriter

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/artifactregistry.reader

gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=serviceAccount:${GCE_SA}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role=roles/batch.agentReporter

gcloud iam service-accounts delete $WORKFLOW_SA@${PROJECT_ID}.iam.gserviceaccount.com --quiet

gcloud iam service-accounts delete $GCE_SA@${PROJECT_ID}.iam.gserviceaccount.com --quiet

gcloud workflows delete $WORKFLOW_NAME --location $REGION --quiet

gcloud artifacts repositories delete $AR_REPO --location $REGION --quiet

gcloud compute networks subnets delete $SUBNET --region $REGION --quiet

gcloud compute networks delete $VPC --quiet
```