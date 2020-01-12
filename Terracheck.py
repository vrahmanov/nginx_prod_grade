from time import strftime, sleep
import boto3
import wget
from python_terraform import *
import argparse
import datetime
import sys
import time
from botocore.exceptions import ParamValidationError, ClientError


def dynamo_db_backend(region, table, ak, sk):
    dynamodb_client = boto3.client('dynamodb', aws_access_key_id=ak,
                                   aws_secret_access_key=sk, region_name=region)

    # response_dynamo = dynamodb_client.describe_table(TableName="vladitest")

    try:
        create = dynamodb_client.create_table(
            AttributeDefinitions=[
                {
                    'AttributeName': 'LockID',
                    'AttributeType': 'S'
                }
            ],
            KeySchema=[
                {
                    'AttributeName': 'LockID',
                    'KeyType': 'HASH',
                }
            ],
            ProvisionedThroughput={
                'ReadCapacityUnits': 5,
                'WriteCapacityUnits': 5,
            },
            TableName=table,
        )
    except ClientError as e:
        print(e)


def artifact_bucket_creation(region, bucketname):
    s3 = boto3.resource('s3')
    if s3.Bucket(bucketname).creation_date is None:
        print("bucket %s does not exist" % bucketname)
        s32 = boto3.client('s3', region_name=region)
        location = {'LocationConstraint': region}
        s32.create_bucket(Bucket=bucketname, CreateBucketConfiguration=location)
    else:
        print("bucket %s exists" % bucketname)


def s3_backend(region, bucket1, ak, sk):
    client = boto3.client(service_name="s3", region_name=region,
                          aws_access_key_id=ak,
                          aws_secret_access_key=sk)
    location = {'LocationConstraint': region}

    try:
        create_bucket_response = client.create_bucket(Bucket=bucket1, CreateBucketConfiguration=location)
    except ClientError as e:
        print(e)


def dynamichange(filename, replacesrc, replacedst):
    try:
        with open(filename) as f:
            s = f.read()
            if replacesrc not in s:
                print('"{replacesrc}" not found in {filename}.'.format(**locals()))
                return

        # Safely write the changed content, if found in the file
        with open(filename, 'w') as f:
            print('Changing "{replacesrc}" to "{replacedst}" in {filename}'.format(**locals()))
            s = s.replace(replacesrc, replacedst)
            f.write(s)
    except Exception as err:
        print('[inplace_change] Error : "{err}'.format(**locals()))
        exit()


def get_aws_account_id():
    return boto3.client('sts').get_caller_identity().get('Account')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-r', help='region to deploy stack example eu-central-1', required=True)
    parser.add_argument('-ak', help='Access Key - Admin rights for this please ', required=True)
    parser.add_argument('-sk', help='Secret Key - Admin rights for this please', required=True)
    args = parser.parse_args()
    dynamo_db_backend(args.r, "terraform-state-db", args.ak, args.sk)
    s3_backend(args.r, "terrform-state-bucket-test", args.ak, args.sk)

    dynamichange('./envparams.tfvars',
                 "SWITCH_REGION",
                 args.r)
    dynamichange('./envparams.tfvars',
                 "SWITCH_AK",
                 args.ak)
    dynamichange('./envparams.tfvars',
                 "SWITCH_SK",
                 args.sk)
    dynamichange('./variables.tf',
                 "SWITCH_BUCKET",
                 "terrform-state-bucket-test")
    dynamichange('./variables.tf',
                 "SWITCH_KEY",
                 "tfproject-key" + args.r)

    dynamichange('./variables.tf',
                 "SWITCH_REGION",
                 args.r)
    dynamichange('./variables.tf',
                 "SWITCH_DYNAMO",
                 "terraform-state-db")

    try:
        tf = Terraform(
            working_dir='./')
        tf.init()
        tf.apply(var_file='envparams.tfvars', skip_plan=True, no_color=IsFlagged, refresh=True,
                 capture_output=False)


    except Exception as err:
        print(err)


main()
