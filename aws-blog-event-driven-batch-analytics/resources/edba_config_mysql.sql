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
job_min_file_count int,
job_addl_criteria varchar(1000),
job_params varchar(1000),
last_exec_stepid varchar(50),
last_exec_status varchar(20),
last_run_timestamp timestamp
);
