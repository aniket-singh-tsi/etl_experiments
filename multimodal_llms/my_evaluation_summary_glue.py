import json
import os
import sys
from typing import Any, Dict, List

from awsglue.utils import getResolvedOptions
from pydantic import ValidationError
from quickstep_etl.tasks.evaluation_helpers.base_evaluator import ETLBaseEvaluator
from quickstep_etl.tasks.evaluation_metrics import ETLEvaluationSummarizer
from quickstep_etl.utils.config_loader import ConfigLoader
from quickstep_etl.utils.credentials import CredentialManager
from quickstep_etl.utils.file_processor import FileProcessor
from quickstep_etl.utils.logger import logger


class MyETLEvaluationSummarizer(ETLEvaluationSummarizer):
    def evaluation_summarizer_processor(self) -> None:
        """
        Main evaluation processor that runs recall and RAGAS evaluations on all CSV files in the source directory.
        """
        try:
            csv_files = self.list_csv_files()
            overall_summary_data = []
            processed_configs = set()
            # import ipdb

            # print("see which csv files get used")
            # ipdb.set_trace()
            for file in csv_files:
                df = self.read_csv_file(file)
                if self.recall_method:
                    if not df["chunk_ids"].isnull().all():
                        self.do_standalone_recall_evaluation(
                            df, processed_configs, overall_summary_data
                        )
                    else:
                        logger.warning(
                            f"'chunk_ids' column is missing or empty in file: {file}. Skipping recall processing and proceeding with only RAGAS/LLM based evaluation."
                        )
                config_model_map = ETLBaseEvaluator.process_configs(df.columns)
                self.do_advanced_evaluation(df, config_model_map)

            if False:
                # Archive retrieve Source
                try:
                    archived_path = self.source_processor.archive(
                        self.source_directory, self.job_id
                    )
                    # archived_target_path = self.target_processor.archive(
                    #     self.target_directory, self.job_id
                    # )
                    logger.info(f"Source data archived to {archived_path}")
                    # logger.info(f"Output data archived to {archived_target_path}")
                except FileNotFoundError:
                    logger.warning(
                        f"Source directory {self.source_directory},{self.target_directory} not found, skipping archive"
                    )
                except Exception as e:
                    logger.warning(f"Failed to archive source data: {str(e)}")

        except Exception as e:
            logger.error(f"Error during evaluation: {e}")
            raise


def main(args: Dict[str, Any]) -> None:
    """
    Main function to run the data cleaning process.
    """
    try:
        config = ConfigLoader(
            arn=args["API_PROXY_ARN"],
            api_url=args["ETL_API_URL"],
            tenant_id=args["TENANT_ID"],
            job_id=args["ETL_JOB_ID"],
            config_file_path="evaluation-config.json",  # For Only Local Testing
        )

        # Extract the necessary configuration values
        config_default = config.get_value(["context", "default"])
        config_evaluation_summary = config.get_value(["context", "evaluationSummary"])
        job_id = config.get_value(["id"])

        bucket_name = config_default.get("s3BucketName")
        source_key = "retrieve-response-data"
        target_key = "evaluation-summary-data"
        evaluate_llm_provider = config_evaluation_summary.get("llmProvider")
        evaluate_llm_model = config_evaluation_summary.get("llmModel")
        evaluate_llm_cred = config_evaluation_summary.get("credentialStore")
        use_evaluators = config_evaluation_summary.get("useEvaluators")
        # Initialize source and target processors

        cred_manager = CredentialManager(
            cred_url=args["CRED_URL"],
            tenant_id=args["TENANT_ID"],
            arn=args["API_PROXY_ARN"],
            cred_values=evaluate_llm_cred,
        )
        llm_api_key = cred_manager.get_credentials("llm", evaluate_llm_provider)

        source_processor = FileProcessor(f"s3://{bucket_name}")
        # target_processor = FileProcessor(f"s3://{bucket_name}")
        mydir = os.path.dirname(os.path.abspath(__file__))
        results_dir = os.path.join(mydir, "tmp_results")
        target_processor = FileProcessor(results_dir)
        # Initialize cleaning processor
        summarizer = MyETLEvaluationSummarizer(
            source_processor=source_processor,
            source_directory=source_key,
            target_processor=target_processor,
            target_directory=target_key,
            llm_provider=evaluate_llm_provider,
            llm_api_key=llm_api_key,
            llm_model_name=evaluate_llm_model,
            use_evaluators=use_evaluators,
            job_id=job_id,
        )
        summarizer.evaluation_summarizer_processor()

    except Exception as e:
        logger.error(f"Critical error in summarize process: {str(e)}")
        raise RuntimeError(f"Evaluation metrics process failed: {str(e)}") from e


if __name__ == "__main__":
    args_name = ["TENANT_ID", "ETL_JOB_ID", "ETL_API_URL", "API_PROXY_ARN", "CRED_URL"]
    args = getResolvedOptions(sys.argv, args_name)
    main(args)
