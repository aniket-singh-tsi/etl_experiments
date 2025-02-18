# Comparing vision+language and language capabilities of LLMs

contains code for comparing how well LLMs perform when queried with just text chunks vs when queried with images + text. 

__Workflow__
From the workspace folder of etl-data-pipelines, first run till the generate-ground-truth job. (Note the ground truth is generated using the text chunks)

```./reinstall.sh &&  bash etl_experiments/multimodal_llms/generate_gt_trigger.sh```

Then run the compare script, to create evaluations of text and text+vision based pipelines:

```./reinstall.sh && bash etl_experiments/multimodal_llms/compare_multimodal_trigger.sh```


TODO: to compare the metrics/results use the jupyter notebook:

```etl_experiments/multimodal_llms/comparison.ipynb```