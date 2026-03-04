import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
const ddbDocClient = DynamoDBDocumentClient.from(client);

export interface LogEntry {
  level: 'INFO' | 'WARN' | 'ERROR';
  event: 'AUTHZ_ALLOW' | 'AUTHZ_DENY' | 'TOKEN_INVALID' | 'HEALTH_CHECK' | 'API_REQUEST';
  requestId: string;
  userId?: string;
  message: string;
  details?: any;
  timestamp: string;
}

export const logger = {
  log: async (entry: Omit<LogEntry, 'timestamp'>) => {
    const fullEntry: LogEntry = {
      ...entry,
      timestamp: new Date().toISOString()
    };
    
    // Console log for CloudWatch
    console.log(JSON.stringify(fullEntry));

    // Audit log to DynamoDB (if table name is provided)
    if (process.env.AUDIT_TABLE_NAME && entry.event.startsWith('AUTHZ_')) {
      try {
        await ddbDocClient.send(new PutCommand({
          TableName: process.env.AUDIT_TABLE_NAME,
          Item: {
            PK: `AUDIT#${fullEntry.timestamp.split('T')[0]}`,
            SK: `${fullEntry.timestamp}#${entry.requestId}`,
            ...fullEntry
          }
        }));
      } catch (err) {
        console.error("Audit log failed to DynamoDB", err);
      }
    }
  }
};

export * from './types.js';
