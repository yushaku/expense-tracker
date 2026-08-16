#!/usr/bin/env node
// apps/mcp-server/src/index.ts

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

// MCP Server
const server = new Server(
  {
    name: 'expense-tracker',
    version: '0.1.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tools list
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'add_expense',
      description: 'Thêm một khoản chi tiêu mới',
      inputSchema: {
        type: 'object',
        properties: {
          amount: { type: 'number', description: 'Số tiền (> 0)' },
          currency: { type: 'string', enum: ['VND', 'USD', 'EUR'], description: 'Đơn vị tiền tệ', default: 'VND' },
          category: {
            type: 'string',
            enum: ['food', 'transport', 'shopping', 'entertainment', 'healthcare', 'education', 'bills', 'savings', 'other'],
            description: 'Danh mục chi tiêu',
          },
          description: { type: 'string', description: 'Mô tả chi tiêu' },
          date: { type: 'string', description: 'Ngày chi tiêu (ISO 8601)' },
          walletId: { type: 'string', description: 'ID ví nguồn' },
          merchant: { type: 'string', description: 'Merchant (optional)' },
          dryRun: { type: 'boolean', description: 'Validate only, no write' },
          clientRequestId: { type: 'string', description: 'Idempotency key' },
        },
        required: ['amount', 'category', 'walletId', 'clientRequestId'],
      },
    },
    {
      name: 'get_wallets',
      description: 'Lấy danh sách ví',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'search_transactions',
      description: 'Tìm giao dịch',
      inputSchema: {
        type: 'object',
        properties: {
          from: { type: 'string', description: 'Từ ngày (ISO 8601)' },
          to: { type: 'string', description: 'Đến ngày (ISO 8601)' },
          walletId: { type: 'string', description: 'ID ví' },
          category: { type: 'string', description: 'Danh mục' },
          type: { type: 'string', enum: ['expense', 'income'], description: 'Loại giao dịch' },
          text: { type: 'string', description: 'Tìm theo text' },
          includeVoided: { type: 'boolean', description: 'Bao gồm đã void' },
          limit: { type: 'number', description: 'Số lượng tối đa', default: 50 },
          offset: { type: 'number', description: 'Bắt đầu từ', default: 0 },
        },
      },
    },
  ],
}));

// Tool call handler
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args = {} } = request.params;

  try {
    switch (name) {
      case 'add_expense':
        return {
          content: [{ type: 'text', text: JSON.stringify({ message: 'Tool not yet implemented', tool: name, args }, null, 2) }],
        };
      case 'get_wallets':
        return {
          content: [{ type: 'text', text: JSON.stringify({ message: 'Tool not yet implemented', tool: name }, null, 2) }],
        };
      case 'search_transactions':
        return {
          content: [{ type: 'text', text: JSON.stringify({ message: 'Tool not yet implemented', tool: name, args }, null, 2) }],
        };
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [{ type: 'text', text: JSON.stringify({ error: (error as Error).message }, null, 2) }],
      isError: true,
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Expense Tracker MCP Server running...');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});