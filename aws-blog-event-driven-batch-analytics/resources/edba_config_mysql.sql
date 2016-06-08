create table ingestedfilestatus(
file_url varchar(500) primary key,
submitted_jobs json,
last_update_status varchar(50),
last_validated_timestamp timestamp,
unique(file_url,last_update_status)
);

create table edbaconfig.aggrjobconfiguration(
job_config_id varchar(10) primary key,
job_input_pattern varchar(500),
job_addl_criteria varchar(1000),
job_params varchar(1000),
last_exec_stepid varchar(50),
last_exec_status varchar(20),
last_run_timestamp timestamp
);
insert into aggrjobconfiguration(job_config_id,job_input_pattern,job_params,last_exec_stepid,last_exec_status,last_run_timestamp,job_addl_criteria) values('Job101','event-driven-batch-analytics/data/validated/OH%.csv','spark-submit,--deploy-mode,cluster,—class,com.amazonaws.bigdatablog.edba.ProcessSalesData,s3://event-driven-batch-analytics/code/eventdrivenbatchanalytics.jar',null,null,null,null);
insert into aggrjobconfiguration(job_config_id,job_input_pattern,job_params,last_exec_stepid,last_exec_status,last_run_timestamp,job_addl_criteria) values('Job102','event-driven-batch-analytics/data/validated/CA%.csv','spark-submit,--deploy-mode,cluster,—class,com.amazonaws.bigdatablog.edba.ProcessSalesData,s3://event-driven-batch-analytics/code/eventdrivenbatchanalytics.jar',null,null,null,null);
insert into aggrjobconfiguration(job_config_id,job_input_pattern,job_params,last_exec_stepid,last_exec_status,last_run_timestamp,job_addl_criteria) values('Job110','event-driven-batch-analytics/data/validated/%.csv','spark-submit,--deploy-mode,cluster,—class,com.amazonaws.bigdatablog.edba.ProcessSalesData,s3://event-driven-batch-analytics/code/eventdrivenbatchanalytics.jar',null,null,null,'select 1 from ingestedfilestatus where file_url like \'%ITEM.csv\' group by file_url  having count(file_url) > 0');
