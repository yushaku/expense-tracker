#!/usr/bin/env node
// apps/mcp-server/src/index.ts

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import Database from 'better-sqlite3';
import {
  generateId,
  DEFAULT_CURRENCY,
  AddExpenseInputSchema,
  ExpenseSchema,
  ExpenseFilterSchema,
  SetBudgetInputSchema,
  BudgetSchema,
  CurrencySchema,
  formatZodError,
  safeParseWithSchema,
} from '@expense/shared';
import type { Expense, ExpenseCategory, ExpenseSummary, SupportedCurrency } from '@expense/shared';

// Database path - iCloud Drive synced folder on macOS
const DB_PATH = process.env.EXPENSE_DB_PATH || 
  `${process.env.HOME}/Library/Mobile Documents/iCloud.com/expense-tracker/expenses.db`;

let db: Database.Database;

function initDatabase() {
  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  
  db.exec(`
    CREATE TABLE IF NOT EXISTS expenses (
      id TEXT PRIMARY KEY,
      amount REAL NOT NULL,
      currency TEXT NOT NULL DEFAULT 'VND',
      category TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      sync_status TEXT DEFAULT 'synced'
    );
    
    CREATE TABLE IF NOT EXISTS budgets (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      amount REAL NOT NULL,
      currency TEXT NOT NULL DEFAULT 'VND',
      period TEXT NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    
    CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date);
    CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);
  `);
}

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

// Tools
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
      name: 'get_expenses',
      description: 'Lấy danh sách chi tiêu với bộ lọc',
      inputSchema: {
        type: 'object',
        properties: {
          startDate: { type: 'string', description: 'Từ ngày (ISO 8601)' },
          endDate: { type: 'string', description: 'Đến ngày (ISO 8601)' },
          category: { type: 'string', description: 'Lọc theo danh mục' },
          limit: { type: 'number', description: 'Số lượng tối đa', default: 50 },
          offset: { type: 'number', description: 'Bắt đầu từ', default: 0 },
        },
      },
    },
    {
      name: 'get_summary',
      description: 'Tổng hợp chi tiêu theo khoảng thời gian',
      inputSchema: {
        type: 'object',
        properties: {
          startDate: { type: 'string', description: 'Từ ngày (ISO 8601)' },
          endDate: { type: 'string', description: 'Đến ngày (ISO 8601)' },
          currency: { type: 'string', description: 'Đơn vị tiền tệ', default: 'VND' },
        },
      },
    },
    {
      name: 'delete_expense',
      description: 'Xóa một khoản chi tiêu',
      inputSchema: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'ID của chi tiêu cần xóa' },
        },
        required: ['id'],
      },
    },
    {
      name: 'set_budget',
      description: 'Đặt ngân sách cho một danh mục',
      inputSchema: {
        type: 'object',
        properties: {
          category: { type: 'string', description: 'Danh mục hoặc "all"' },
          amount: { type: 'number', description: 'Hạn mức ngân sách' },
          currency: { type: 'string', description: 'Đơn vị tiền tệ', default: 'VND' },
          period: { type: 'string', enum: ['weekly', 'monthly', 'yearly'], description: 'Chu kỳ' },
        },
        required: ['category', 'amount', 'period'],
      },
    },
    {
      name: 'get_budgets',
      description: 'Lấy danh sách ngân sách',
      inputSchema: { type: 'object', properties: {} },
    },
    {
      name: 'get_statistics',
      description: 'Thống kê chi tiêu chi tiết',
      inputSchema: {
        type: 'object',
        properties: {
          period: { type: 'string', enum: ['week', 'month', 'year'], description: 'Chu kỳ thống kê', default: 'month' },
        },
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args = {} } = request.params;
  
  try {
    switch (name) {
      case 'add_expense': {
        const parsed = safeParseWithSchema(AddExpenseInputSchema, args);
        if (!parsed.success) {
          return {
            content: [{ type: 'text', text: JSON.stringify(formatZodError(parsed.error), null, 2) }],
            isError: true,
          };
        }
        const input = parsed.data;
        const now = new Date().toISOString();
        const expense = ExpenseSchema.parse({
          id: generateId(),
          amount: input.amount,
          currency: input.currency ?? DEFAULT_CURRENCY,
          category: input.category,
          description: input.description ?? '',
          date: input.date ?? now,
          walletId: input.walletId,
          merchant: input.merchant,
          status: 'active',
          clientRequestId: input.clientRequestId,
          createdAt: now,
          updatedAt: now,
        });

        if (input.dryRun) {
          return {
            content: [{ type: 'text', text: JSON.stringify({ dryRun: true, wouldCreate: expense }, null, 2) }],
          };
        }

        db.prepare(`
          INSERT INTO expenses (id, amount, currency, category, description, date, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run(expense.id, expense.amount, expense.currency, expense.category, expense.description, expense.date, expense.createdAt, expense.updatedAt);

        return {
          content: [{ type: 'text', text: JSON.stringify({ success: true, expense }, null, 2) }],
        };
      }

      case 'get_expenses': {
        const filterParsed = safeParseWithSchema(ExpenseFilterSchema, {
          startDate: args.startDate,
          endDate: args.endDate,
          category: args.category,
        });
        if (!filterParsed.success) {
          return {
            content: [{ type: 'text', text: JSON.stringify(formatZodError(filterParsed.error), null, 2) }],
            isError: true,
          };
        }
        const filter = filterParsed.data;
        const limit = (args.limit as number) || 50;
        const offset = (args.offset as number) || 0;
        
        let sql = 'SELECT * FROM expenses WHERE 1=1';
        const params: any[] = [];
        
        if (filter.startDate) {
          sql += ' AND date >= ?';
          params.push(filter.startDate);
        }
        if (filter.endDate) {
          sql += ' AND date <= ?';
          params.push(filter.endDate);
        }
        if (filter.category) {
          sql += ' AND category = ?';
          params.push(filter.category);
        }
        
        sql += ' ORDER BY date DESC LIMIT ? OFFSET ?';
        params.push(limit, offset);
        
        const expenses = db.prepare(sql).all(...params);
        
        return {
          content: [{ type: 'text', text: JSON.stringify({ expenses, total: expenses.length }, null, 2) }],
        };
      }
      
      case 'get_summary': {
        const startDate = args.startDate as string || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
        const endDate = args.endDate as string || new Date().toISOString();
        const currencyParsed = safeParseWithSchema(
          CurrencySchema,
          args.currency ?? DEFAULT_CURRENCY
        );
        if (!currencyParsed.success) {
          return {
            content: [{ type: 'text', text: JSON.stringify(formatZodError(currencyParsed.error), null, 2) }],
            isError: true,
          };
        }
        const currency: SupportedCurrency = currencyParsed.data;
        
        const total = db.prepare(`
          SELECT COALESCE(SUM(amount), 0) as total FROM expenses 
          WHERE date >= ? AND date <= ? AND currency = ?
        `).get(startDate, endDate, currency) as { total: number };
        
        const byCategory = db.prepare(`
          SELECT category, COALESCE(SUM(amount), 0) as total FROM expenses 
          WHERE date >= ? AND date <= ? AND currency = ?
          GROUP BY category
        `).all(startDate, endDate, currency) as Array<{ category: string; total: number }>;
        
        const summary: ExpenseSummary = {
          totalAmount: total.total,
          currency,
          period: { start: startDate, end: endDate },
          byCategory: byCategory.reduce((acc, row) => {
            acc[row.category as ExpenseCategory] = row.total;
            return acc;
          }, {} as Record<ExpenseCategory, number>),
        };
        
        return {
          content: [{ type: 'text', text: JSON.stringify(summary, null, 2) }],
        };
      }
      
      case 'delete_expense': {
        const id = args.id as string;
        const result = db.prepare('DELETE FROM expenses WHERE id = ?').run(id);
        
        return {
          content: [{ type: 'text', text: JSON.stringify({ success: result.changes > 0, deleted: result.changes }, null, 2) }],
        };
      }
      
      case 'set_budget': {
        const budgetInput = safeParseWithSchema(SetBudgetInputSchema, args);
        if (!budgetInput.success) {
          return {
            content: [{ type: 'text', text: JSON.stringify(formatZodError(budgetInput.error), null, 2) }],
            isError: true,
          };
        }
        const now = new Date().toISOString();
        const budget = BudgetSchema.parse({
          id: generateId(),
          category: budgetInput.data.category,
          amount: budgetInput.data.amount,
          currency: budgetInput.data.currency ?? DEFAULT_CURRENCY,
          period: budgetInput.data.period,
          startDate: now,
          endDate: null,
        });

        db.prepare(`
          INSERT INTO budgets (id, category, amount, currency, period, start_date, end_date, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `).run(budget.id, budget.category, budget.amount, budget.currency, budget.period, budget.startDate, budget.endDate, now, now);

        return {
          content: [{ type: 'text', text: JSON.stringify({ success: true, budget }, null, 2) }],
        };
      }
      
      case 'get_budgets': {
        const budgets = db.prepare('SELECT * FROM budgets ORDER BY created_at DESC').all();
        
        return {
          content: [{ type: 'text', text: JSON.stringify({ budgets }, null, 2) }],
        };
      }
      
      case 'get_statistics': {
        const period = (args.period as string) || 'month';
        const now = new Date();
        let startDate: Date;
        
        if (period === 'week') {
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        } else if (period === 'month') {
          startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        } else {
          startDate = new Date(now.getFullYear(), 0, 1);
        }
        
        const expenses = db.prepare(`
          SELECT * FROM expenses WHERE date >= ? ORDER BY date DESC
        `).all(startDate.toISOString()) as Expense[];
        
        const totalAmount = expenses.reduce((sum, e) => sum + e.amount, 0);
        const avgDaily = totalAmount / ((now.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));
        
        const byCategory: Record<string, number> = {};
        expenses.forEach(e => {
          byCategory[e.category] = (byCategory[e.category] || 0) + e.amount;
        });
        
        return {
          content: [{ type: 'text', text: JSON.stringify({
            period,
            totalExpense: totalAmount,
            totalCount: expenses.length,
            averageDaily: Math.round(avgDaily),
            topCategories: Object.entries(byCategory)
              .sort(([, a], [, b]) => b - a)
              .slice(0, 5)
              .map(([category, amount]) => ({ category, amount })),
          }, null, 2) }],
        };
      }
      
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

// Start
async function main() {
  initDatabase();
  
  const transport = new StdioServerTransport();
  await server.connect(transport);
  
  console.error('Expense Tracker MCP Server running...');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
