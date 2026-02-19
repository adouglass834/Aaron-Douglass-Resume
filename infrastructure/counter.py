import json
import boto3
import os

# Connect to DynamoDB
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    # Update the visitor count
    response = table.update_item(
        Key={'id': 'visitor_count'},
        UpdateExpression='ADD quantity :inc',
        ExpressionAttributeValues={':inc': 1},
        ReturnValues='UPDATED_NEW'
    )
    
    count = response['Attributes']['quantity']
    
    # Return the count to the website
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',  # Allow your website to call this
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET'
        },
        'body': json.dumps({'count': str(int(count))})
    }