#!/bin/bash

ETL_API_URL="https://localhost:8080/api/v1/etl-jobs"
API_PROXY_ARN="arn:aws:glue:us-east-1:123456789012:job/quickstep-etl-job"
CRED_URL="http://10.145.31.47:3005/integration/api/v1/"
CONFIG_FILE="evaluation-config.json"

echo " "
echo "======================="
echo "Triggering Evaluation Job"
echo "======================="
echo " "
echo " "
echo "======================="
echo "Checking for .env file"
echo "======================="
echo " "
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs) # Load variables into the environment
    echo "Load .env file DONE"
else
    echo ".env file not found, skipping environment variable loading."
fi
echo " "
echo "======================="
echo "Checking for configuration file"
echo "======================="
echo " "
if [ -f $CONFIG_FILE ]; then
    groundTruthType=$(jq -r '.context.retrieveResponse.groundTruthType' $CONFIG_FILE)
    bucketName=$(jq -r '.context.default.s3BucketName' $CONFIG_FILE)
    gtDataFolder=$(jq -r '.context.retrieveResponse.groundTruthSrcPath' $CONFIG_FILE)
    # prefix=$(jq -r '.context.retrieveResponse.prefix' $CONFIG_FILE)
    region=$(jq -r '.region' $CONFIG_FILE)
    etlJobId=$(jq -r '.id' $CONFIG_FILE)
    tenantId=$(jq -r '.tenantId' $CONFIG_FILE)
    rrDataFolder=$(jq -r '.context.retrieveResponse.retrieveResponseSrcPath' $CONFIG_FILE)
    rRType=$(jq -r '.context.retrieveResponse.retrieveResponseType' $CONFIG_FILE)
    echo "Load evaluation_config.json file DONE"
else
    echo "configuration file not found, exiting."
    exit 1
fi
# Upload groundtruth data to localstack if groundtruth type is static
if [ "$groundTruthType" == "static" ]; then
    echo " "
    echo "======================="
    echo "Uploading static groundtruth data to localstack"
    echo "======================="
    echo " "
    # can we get prefix from somewhere or do we want to set it to the same as dataFolder?
    python3 upload_to_localstack.py \
        --bucket $bucketName \
        --folder ./data/$gtdataFolder \
        --prefix $gtDataFolder \
        --region $region
    echo " "
    echo "Upload static groundtruth data to localstack DONE"
else
    echo " "
    echo "======================="
    echo "GroundTruth creation"
    echo "======================="
    echo " "
    python3 gluejobs/ground_truth.py \
        --TENANT_ID $tenantId \
        --ETL_JOB_ID $etlJobId \
        --ETL_API_URL $ETL_API_URL \
        --API_PROXY_ARN $API_PROXY_ARN \
        --CRED_URL $CRED_URL
    echo "GroundTruth data creation DONE"
fi