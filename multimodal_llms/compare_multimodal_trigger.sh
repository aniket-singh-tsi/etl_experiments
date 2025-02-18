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
# rRType="static"
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
aws --endpoint-url=http://host.docker.internal:4566 s3 rm s3://${bucketName}/${etlJobId}/retrieve-response-data --recursive
if [ "$rRType" == "static" ]; then
    echo " "
    echo "======================="
    echo "Uploading static retrieve response data to localstack"
    echo "======================="
    echo " "
    python3 upload_to_localstack.py \
        --bucket $bucketName \
        --folder ./data/$rrDataFolder \
        --prefix $etlJobId/$rrDataFolder \
        --region $region
    echo "Upload static retrieve response data to localstack DONE"
else

    echo " "
    echo "======================="
    echo "Creating Retrieve Response data"
    echo "======================="
    echo " "
    python3 gluejobs/retrieve_response_glue.py \
        --TENANT_ID $tenantId \
        --ETL_JOB_ID $etlJobId \
        --ETL_API_URL $ETL_API_URL \
        --API_PROXY_ARN $API_PROXY_ARN --CRED_URL $CRED_URL
    echo "Retrieve Response data DONE"
fi
echo " "
echo "======================="
echo "Evaluation Summarize data"
echo "======================="
echo " "
python3 etl_experiments/multimodal_llms/my_evaluation_summary_glue.py \
    --TENANT_ID $tenantId \
    --ETL_JOB_ID $etlJobId \
    --ETL_API_URL $ETL_API_URL \
    --API_PROXY_ARN $API_PROXY_ARN --CRED_URL $CRED_URL
echo "Evaluation Summarize data DONE"
echo " "
echo "======================="
echo "Evaluation Job Completed"
echo "======================="
echo " "