# Building Event Driven Batch Analytics on AWS

## Overview

This repository contains the code that supports the [AWS Big Data Blog Post](https://blogs.aws.amazon.com/bigdata/)

### Usecase Description
Lets take a sample usecase and write code implementing the event driven batch analytics framework we discussed so far. Company ABC Enterprise manufactures copy machines which are sold by its vendors across the country. All these Vendors run on wide variety of platforms and they submit cumulative transaction files to ABC enterprises at varuious cadence levels through out the day in tab delimited .tdf format. Some of these vendors due to their system limitations sometimes send additional data starting with characters such as “----“.

The requirement is to be able to updates insights  on the sales made by each vendor for a given item through out the day as soon as the complete list of vendor files from a given province are available. The number of vendors per province is fixed and seldom changes.

The aggregation job for given province should not be submitted until the configured number of vendor files from that province are available and also until the item master data update is posted at the beginning of the day. A master data update is identified by the presence of atleast one “item.csv” file.

The aggregation job should consider only transaction codes 4 (sale amount) , 5 (tax amount) and 6 (discount amount). Rest of the codes can be ignored. Once the aggregation job is completed only one record should exist for a combination of vendor,item and transaction date


### Pre-Requisites
1. Create VPC with at least one private "MyPrivateSubnet" and one public subnet "MyPublicSubnet"
2. Create a NAT Gateway or NAT Instance for [lambda functions in private subnet](https://aws.amazon.com/blogs/aws/new-access-resources-in-a-vpc-from-your-lambda-functions/) to be able to access internet
3. Create a role "myLambdaRole" with AWSLambdaVPCAccessExecution, AWSLambdaRole, ElasticMapReduceForEC2Role,S3 and Cloudwatch access policies
4. Create security group "MySecurityGroup" with inbound MySQL (3306) and Redshift (5439) ports open.
5. Jar file with all dependencies is already available in S3 at this location. Download it your local environment [location](s3://event-driven-batch-analytics/code/eventdrivenbatchanalytics.jar).
6. If you wish to build your own jar,download mySQL JDBC driver and Redshift JDBC Driver and add it to your maven repository

### Getting Started

1. [Create a Amazon RDS Mysql 5.7.x instance](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_GettingStarted.CreatingConnecting.MySQL.html)
2. Connect to the mysql database instance through your preferred SQL client and execute sql statements inside resources/edba_config_mysql.sql
3. Create a two node ds2.xlarge Redshift cluster .
4. Connect to the cluster through your preferred SQL client and execute statements inside resources/edba_redshift.sql file

5. Create S3 bucket

  ```
  aws s3 mb event-driven-batch-analytics
  ```
6. Create Validation/Conversion Layer Lambda function

  ```
  aws lambda create-function --function-name validateAndNormalizeInputData --zip-file fileb:///<<MyPath>>/eventdrivenbatchanalytics.jar --handler com.amazonaws.bigdatablog.edba.LambdaContainer::validateAndNormalizeInputData --role arn:aws:iam::<<myAccountNumber>>:role/<<myLambdaRole>> --runtime java8 --timeout 120
  ```
7. Provide S3 permissions to invoke the Validation Layer lambda function

  ```
  aws lambda add-permission --function-name auditValidatedFile --statement-id 2222 --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn arn:aws:s3:::event-driven-batch-analytics --source-account <<MyAccount>>
  ```
9. Create "Input Tracking Layer" lambda function

  ```
  aws lambda create-function --function-name  auditValidatedFile --zip-file fileb:///<<MyPath>>/eventdrivenbatchanalytics.jar --handler com.amazonaws.bigdatablog.edba.LambdaContainer::auditValidatedFile --role arn:aws:iam::<<myAccountNumber>>:role/lambdas3eventprocessor --runtime java8 --vpc-config '{"SubnetIds":["MyPrivateSubnet"],"SecurityGroupIds":["MySecurityGroup"]}' --memory-size 1024 --timeout 120
  ```
10. Provide S3 permissions to invoke "Input Tracking Layer" lambda function

  ```
  aws lambda add-permission --function-name auditValidatedFile --statement-id 2222 --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn arn:aws:s3:::event-driven-batch-analytics --source-account 203726645967
  ```
11. Configure events in S3 to trigger "Validation/Conversion Layer" and "Input Tracking Layer" lambda functions

  ```
  aws s3api put-bucket-notification-configuration --notification-configuration file:///<<MyPath>>/put-bucket-notification.json --bucket event-driven-batch-analytics
  ```
12. Create EMR Job Submission Layer lambda function. This function will submit a EMR job if the respective configured  criteria has been passed  

  ```
  aws lambda create-function --function-name  checkCriteriaFireEMR --zip-file fileb:///<<MyPath>>/eventdrivenbatchanalytics-0.0.1-SNAPSHOT.jar --handler com.amazonaws.bigdatablog.edba.LambdaContainer::checkConditionStatusAndFireEMRStep --role arn:aws:iam::<<myAccountNumber>>:role/lambdas3eventprocessor --runtime java8 \
  --vpc-config '{"SubnetIds":["MyPrivateSubnet"],"SecurityGroupIds":["MySecurityGroup"]}' --memory-size 1024 --timeout 300
  ```
13. Schedule CloudWatch Event to fire every 10 minutes to verify whether any Aggregation Job submission criteria is passed

  ```
  aws events put-rule --name scheduledEMRJobRule --schedule-expression 'rate(10 minutes)'
  ```
14. Give CloudWatch events rule permission to invoke "scheduledEMRJobRule" lambda function

  ```
  aws lambda add-permission \
  --function-name checkCriteriaFireEMR \
  --statement-id checkCriteriaFireEMR \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com --source-arn  arn:aws:events:us-east-1:<<myAccountNumber>>:rule/scheduledEMRRule
  ```
15. Configure "checkCriteriaFireEMR" Lambda function as target for the "scheduledEMRJobRule" CloudWatch event rule

  ```
  aws events put-targets --rule scheduledEMRJobRule  --targets '{"Id" : "1", "Arn": "arn:aws:lambda:us-east-1:<<myAccountNumber>>:function:checkCriteriaFireEMR"}'
  ```
16. Create EMR Job Monitoring Layer lambda function. This function will update AGGRJOBCONFIGURATION table with status of a RUNNING EMR step

  ```
  aws lambda create-function --function-name  monitorEMRAggregationJob --zip-file fileb:///<<MyPath>>/eventdrivenbatchanalytics-0.0.1-SNAPSHOT.jar --handler com.amazonaws.bigdatablog.edba.LambdaContainer::monitorEMRStep --role arn:aws:iam::<<myAccountNumber>>:role/lambdas3eventprocessor --runtime java8 \
  --vpc-config '{"SubnetIds":["MyPrivateSubnet"],"SecurityGroupIds":["MySecurityGroup"]}' --memory-size 500 --timeout 300
  ```
17. Schedule CloudWatch Event to monitor submitted EMR jobs  every 15 minutes

  ```
  aws events put-rule --name monitorEMRJobRule --schedule-expression 'rate(15 minutes)'
  ```
18. Give Cloudwatch event rule permission to invoke "monitorEMRAggregationJob" lambda function

  ```
  aws lambda add-permission \
  --function-name monitorEMRAggregationJob \
  --statement-id monitorEMRAggregationJob \
  --action 'lambda:InvokeFunction' \
  --principal events.amazonaws.com --source-arn  arn:aws:events:us-east-1:<<myAccountNumber>>:rule/monitorEMRJobRule
  ```
19. Configure "monitorEMRAggregationJob" lambda function as target for "monitorEMRJobRule"

  ```
  aws events put-targets --rule monitorEMRJobRule  --targets '{"Id" : "1", "Arn": "arn:aws:lambda:us-east-1:<<myAccountNumber>>:function:monitorEMRAggregationJob"}'
  ```
20. Download the files from resource/sampledata/ to your local directory and from the directory where you downloaded the files to, upload them to S3://event-driven-batch-analytics/ with prefix data/source-identical

  ```
  aws s3 sync . s3://event-driven-batch-analytics/data/source-identical/
  ```
21. Observe the timestamps of CloudWatch logs for each of the lambda functions being created and updated. Notice that there are no errors recorded
21) After around 10 minutes, connect to the MySQL client and verify whether any jobs have been submitted. The schedule interval will determine the delay

  ```
  select job_config_id from aggrjobconfiguration where last_exec_status = 'RUNNING';
  ```
22. Connect to the redshift cluster and verify that the data in the tables "vendortranssummary" is populated

23. If for any reason a job is failed, execute the below query to find out the impacted files

  ```
  select t1.job_config_id,t2.file_url,t2.last_validated_timestamp from aggrjobconfiguration t1 join ingestedfilestatus t2 on json_contains(t2.submitted_jobs,json_array(t1.job_config_id))=1 where t1.last_exec_status='FAILED';
  ```
