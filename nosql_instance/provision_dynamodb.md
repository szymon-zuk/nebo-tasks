# NeBo Task: Provision a NoSQL Instance (DynamoDB)

## Objective
This task demonstrates provisioning and working with a **NoSQL database** on AWS using **Amazon DynamoDB**.  
Commands provided will create a table named **`Games`**, insert sample data and perform CRUD and query operations — all within the **AWS Free Tier**.

---

## Acceptance Criteria

| Requirement | Method | Status |
|--------------|---------|---------|
| Created Table on DynamoDB | AWS Console or CLI | ✅ |
| Data written to Table | AWS CLI (`put-item`) | ✅ |
| Data readable from Table | AWS CLI (`get-item`, `scan`, `query`) | ✅ |
| Updated data in Table | AWS CLI (`update-item`) | ✅ |
| Query data in Table | AWS CLI (`query`, `scan`) | ✅ |
| Create Global Secondary Index (GSI) | AWS CLI (`update-table`) | ✅ |
| Query GSI | AWS CLI (`query --index-name`) | ✅ |

---

## Step 1 - create the DynamoDB table
```bash
aws dynamodb create-table \
  --table-name Games \
  --attribute-definitions AttributeName=gameId,AttributeType=S \
  --key-schema AttributeName=gameId,KeyType=HASH \
  --billing-mode PROVISIONED \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --table-class STANDARD

aws dynamodb wait table-exists --table-name Games
```
## Step 2 - Insert Data into the table
```bash
aws dynamodb put-item --table-name Games --item '{
  "gameId": {"S":"GAME#001"},
  "title": {"S":"Dota 2"},
  "genre": {"S":"MOBA"},
  "developer": {"S":"Valve"},
  "releaseYear": {"N":"2013"}
}'

aws dynamodb put-item --table-name Games --item '{
  "gameId": {"S":"GAME#002"},
  "title": {"S":"Counter-Strike 2"},
  "genre": {"S":"FPS"},
  "developer": {"S":"Valve"},
  "releaseYear": {"N":"2023"}
}'

```
## Step 3 - read data
Retrieve specific items:
```bash
aws dynamodb get-item --table-name Games --key '{
  "gameId": {"S":"GAME#001"}
}'
```
Scan all the records:
```bash
aws dynamodb scan --table-name Games
```

## Step 4 - updating data
```bash
aws dynamodb update-item --table-name Games \
  --key '{"gameId":{"S":"GAME#002"}}' \
  --update-expression "SET genre = :g" \
  --expression-attribute-values '{":g":{"S":"Tactical Shooter"}}' \
  --return-values ALL_NEW
```

## Step 5 - query the table to get the data
```bash
aws dynamodb query \
  --table-name Games \
  --key-condition-expression "gameId = :id" \
  --expression-attribute-values '{":id":{"S":"GAME#001"}}'
```

## Step 6 - create GSI (Global Secondary Index)
```bash
aws dynamodb update-table \
  --table-name Games \
  --attribute-definitions AttributeName=genre,AttributeType=S \
  --global-secondary-index-updates '[
    {
      "Create": {
        "IndexName": "genre-index",
        "KeySchema": [{"AttributeName":"genre","KeyType":"HASH"}],
        "Projection": {"ProjectionType":"ALL"},
        "ProvisionedThroughput": {"ReadCapacityUnits":1,"WriteCapacityUnits":1}
      }
    }
  ]'
```
then wait for the index to become active

```bash
aws dynamodb describe-table --table-name Games \
  --query "Table.GlobalSecondaryIndexes[?IndexName=='genre-index'].IndexStatus"
```

## Step 7 - query the Global Secondary Index
```bash
aws dynamodb query \
  --table-name Games \
  --index-name genre-index \
  --key-condition-expression "genre = :g" \
  --expression-attribute-values '{":g":{"S":"FPS"}}'
```

## Step 8 - cleanup of the table
```bash
aws dynamodb delete-table --table-name Games
aws dynamodb wait table-not-exists --table-name Games
```

## Summary

- Created: Table Games
- Inserted: Dota 2, Counter-Strike 2
- Read / Updated / Queried: Verified via CLI
- Added GSI: genre-index