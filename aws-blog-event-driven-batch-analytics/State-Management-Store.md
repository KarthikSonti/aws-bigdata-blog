

## State Management Store

A simple statement management store can be accomplished with two tables: one for storing aggregation job configurations (AGGRJOBCONFIGURATION) and another for storing the ingested file status (INGESTEDFILESTATUS). Here are the columns in each table and their descriptions. The DDL and the EMR job configurations for the tracking store can be found here



### AGGRJOBCONFIGURATION
| Column | Description |
| ------ | -------------- |
| job_config_id | Job Configuration Identifier |
| job_input_pattern | The file pattern that this job cares about. The EMR Job Submission Layer lambda function checks whether the timestmap for these files is later than the timestamp when the job ran last time |
| job_min_file_count | The minimum number of files that should be collected before submitting this job |
| job_addl_criteria | In addition to the default timestamp check (explained above), if your job configuration needs additional criteria, express your criteria in the form of SQL statement |
| job_params | EMR step configuration parmaeters (example: spark-submit, --deploy-mode cluster, class, jar etc) |
| last_exec_stepid | The last submitted EMR step id . A combination of clusterid:stepid will be stored in this column |
| last_exec_status | The status (COMPLETED/FAILED/RUNNING) of the EMR step that has been submitted for this configuration |
| last_run_timestamp | The last time when this job was run. |

##### Sample AGGRJOBCONFIGURATION Records

Here are the sample records for the use case we are walking through. The job configuration "J101" indicates that there need be at least 11 files collected from Illinois, identified by having IL in the file prefix,  and an update from on Item master data, identified by Item%.csv, posted in the last 24 hours

The job configuration "J102" is similar to the configuration "J101" with the exception that the file prefix will have "CA" for California province files and the number of vendor transactions to be collected are at least 25

| job_config_id	 | job_input_pattern |	job_min_file_count |	job_params |	additional_criteria |	last_exec_stepid	| last_exec_status |	last_run_timestamp |
| --- | --- | --- | --- | --- | --- | --- | -- |
| J101 |	ingestedfilestatus.file_url like %validated%IL%.csv |	11 | spark-submit,--deploy-mode,cluster,—class,com.amazonaws.bigdatablog.edba.emr.ProcessVendorTransactions,s3://event-driven-batch-analytics/code/eventdrivenanalytics.jar s3://event-driven-batch-analytics/data/validated/%IL%.csv | select 1 from ingestedfilestatus where file_url like '%Item%.csv' and last_validated_timestamp > current_timestamp - interval 1 day | |  | |
| J102 |	ingestedfilestatus.file_url like %validated%CA%.CSV	| 25 | spark-submit,--deploy-mode,cluster,—class,com.awsblogs.bigdata.AggregateTransInfo,s3://event-driven-batch-analytics/code/aggregatetransinfo.jar s3://event-driven-batch-analytics/data/validated/%CA%.csv |	select 1 from ingestedfilestatus where file_url like '%Item%.csv' and last_validated_timestamp > current_timestamp - interval 1 day |  | | |			


### INGESTEDFILESTATUS
| Column | Description |
| ------ | ------------ |
| file_url | The complete key  of the input file including the bucket name |
| submitted_jobs | A JSON list  the jobs that were submitted  with this file.  When a new update of this file is received , this array will be reset to null. By a  join on this column and job_config_id  column AGGRJOBCONFIGURATION table ,  the files related to a FAILED job or RUNNING job or COMPLETED job can be obtained |
| last_update_status | Indicates whether the latest update on this file has been validated or not |
| last_validated_timestamp | The last time when a valid update on this file is received |

These two tables are read by the Lambda functions in the EMR Job Submission and Monitoring Layer that we are going to see next. A variation of this design is to have code component to be executed for “additional_criteria” instead of sql statements and may be also to extend it to beyond EMR (for example, a Data Pipeline job). The data models shown here are just an indication of how this layer can be used. You may need to tweak them to suit your specific need.
