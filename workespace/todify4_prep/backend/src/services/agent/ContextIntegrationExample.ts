/**
 * 统一上下文管理器集成示例
 * 演示如何在 AgentOrchestrator 中使用新的压缩机制
 */

import { UnifiedContextManager, PRESET_CONFIGS, CompressionConfig } from './UnifiedContextManager';
import { ChatMessage } from '../llm/types';

/**
 * 示例1：在 AgentOrchestrator 中集成
 */
export class AgentOrchestratorWithCompression {
  private contextManager: UnifiedContextManager;

  constructor() {
    this.contextManager = new UnifiedContextManager();
  }

  /**
   * 执行 Agent（带上下文压缩）
   */
  async executeAgent(
    roleId: string,
    query: string,
    conversationId: string,
    context: Record<string, any> = {}
  ) {
    // 1. 根据 Agent 类型选择压缩配置
    const compressionConfig = this.selectCompressionConfig(roleId, context);

    // 2. 获取压缩后的上下文
    const compressed = await this.contextManager.getCompressedContext(
      conversationId,
      compressionConfig
    );

    console.log(`[上下文压缩] 原始: ${compressed.metadata.originalCount}条/${compressed.metadata.originalTokens}tokens`);
    console.log(`[上下文压缩] 压缩后: ${compressed.metadata.compressedCount}条/${compressed.metadata.compressedTokens}tokens`);
    console.log(`[上下文压缩] 压缩比: ${(compressed.metadata.compressionRatio * 100).toFixed(1)}%`);

    // 3. 使用压缩后的上下文调用 LLM
    const messages: ChatMessage[] = [
      ...compressed.messages,
      { role: 'user', content: query }
    ];

    // 4. 调用 LLM (示例代码)
    // const response = await this.llmProvider.chat(messages, config);
    
    return {
      content: '响应内容',
      metadata: {
        compressionStats: compressed.metadata,
      },
    };
  }

  /**
   * 根据场景选择压缩配置
   */
  private selectCompressionConfig(roleId: string, context: Record<string, any>) {
    // 检查角色配置中是否指定了场景
    const scenarioType = context.scenarioType || this.inferScenario(roleId);

    switch (scenarioType) {
      case 'quick_chat':
        return PRESET_CONFIGS.quick_chat;
      
      case 'tech_wrapping':
        return {
          ...PRESET_CONFIGS.tech_wrapping,
          // 动态提取关键词
          keywords: this.extractKeywords(context),
        };
      
      case 'brainstorm':
        return PRESET_CONFIGS.brainstorm;
      
      default:
        return {}; // 使用默认配置
    }
  }

  /**
   * 推断场景类型
   */
  private inferScenario(roleId: string): string {
    // 根据角色ID或名称推断
    if (roleId.includes('marketing') || roleId.includes('tech_director')) {
      return 'tech_wrapping';
    }
    
    if (roleId.includes('brainstorm')) {
      return 'brainstorm';
    }
    
    return 'quick_chat';
  }

  /**
   * 从上下文中提取关键词
   */
  private extractKeywords(context: Record<string, any>): string[] {
    const keywords: string[] = [];
    
    if (context.techDocument) {
      // 从技术文档中提取术语（简化实现）
      const text = context.techDocument as string;
      const matches = text.match(/[A-Z]{2,}|[\u4e00-\u9fa5]{2,5}/g);
      if (matches) {
        keywords.push(...matches.slice(0, 8));
      }
    }
    
    if (context.topic) {
      keywords.push(context.topic);
    }
    
    return [...new Set(keywords)]; // 去重
  }
}

/**
 * 示例2：替换旧的 ContextManager
 */
export class LegacyContextManagerAdapter {
  private unifiedManager: UnifiedContextManager;

  constructor() {
    this.unifiedManager = new UnifiedContextManager();
  }

  /**
   * 兼容旧接口：getContextMessages
   */
  async getContextMessages(
    conversationId: string,
    strategy: any, // 旧的策略配置
    currentQuery: string
  ): Promise<ChatMessage[]> {
    // 将旧策略转换为新配置
    const config: Partial<CompressionConfig> = this.convertLegacyStrategy(strategy);

    // 从当前查询中提取关键词
    config.keywords = this.extractKeywordsFromQuery(currentQuery);

    // 调用新的统一管理器
    const compressed = await this.unifiedManager.getCompressedContext(
      conversationId,
      config
    );

    return compressed.messages;
  }

  /**
   * 转换旧策略配置
   */
  private convertLegacyStrategy(strategy: any) {
    const type = strategy?.type || 'window';

    switch (type) {
      case 'window':
        return {
          recentWindow: strategy.maxMessages || 10,
          enableSemanticCompression: false,
        };

      case 'summary':
        return {
          recentWindow: strategy.maxMessages || 10,
          enableSemanticCompression: true,
          tokenBudget: 4000,
        };

      case 'hybrid':
        return {
          recentWindow: strategy.maxMessages || 20,
          tokenBudget: strategy.maxTokens || 4000,
          enableSemanticCompression: true,
        };

      default:
        return {};
    }
  }

  /**
   * 从查询中提取关键词
   */
  private extractKeywordsFromQuery(query: string): string[] {
    // 简单分词（可以使用更复杂的NLP工具）
    const keywords = query
      .split(/[\s，,。.;；：:]+/)
      .map(word => word.trim())
      .filter(word => word.length >= 2 && word.length <= 20);

    return keywords.slice(0, 5);
  }
}

/**
 * 示例3：监控和统计
 */
export class ContextCompressionMonitor {
  private stats: CompressionStats = {
    totalCompressions: 0,
    totalTokensSaved: 0,
    totalCompressionTime: 0,
    compressionRatios: [],
  };

  /**
   * 记录压缩事件
   */
  recordCompression(metadata: any) {
    this.stats.totalCompressions++;
    this.stats.totalTokensSaved += (metadata.originalTokens - metadata.compressedTokens);
    this.stats.totalCompressionTime += metadata.compressionTime;
    this.stats.compressionRatios.push(metadata.compressionRatio);
  }

  /**
   * 获取统计数据
   */
  getStats() {
    const avgRatio = this.stats.compressionRatios.length > 0
      ? this.stats.compressionRatios.reduce((a, b) => a + b, 0) / this.stats.compressionRatios.length
      : 0;

    const avgTime = this.stats.totalCompressions > 0
      ? this.stats.totalCompressionTime / this.stats.totalCompressions
      : 0;

    // 估算成本节省（假设 $0.002 per 1K tokens）
    const costSavings = (this.stats.totalTokensSaved / 1000) * 0.002;

    return {
      totalCompressions: this.stats.totalCompressions,
      avgCompressionRatio: avgRatio,
      avgCompressionTime: avgTime,
      totalTokensSaved: this.stats.totalTokensSaved,
      costSavings: `$${costSavings.toFixed(2)}`,
    };
  }

  /**
   * 重置统计
   */
  reset() {
    this.stats = {
      totalCompressions: 0,
      totalTokensSaved: 0,
      totalCompressionTime: 0,
      compressionRatios: [],
    };
  }
}

interface CompressionStats {
  totalCompressions: number;
  totalTokensSaved: number;
  totalCompressionTime: number;
  compressionRatios: number[];
}

/**
 * 示例4：自定义压缩策略
 */
export class CustomCompressionStrategy {
  private contextManager: UnifiedContextManager;

  constructor() {
    this.contextManager = new UnifiedContextManager();
  }

  /**
   * 场景：长文档分析（需要保留所有技术细节）
   */
  async getLongDocumentContext(conversationId: string, documentSize: number) {
    const config = {
      recentWindow: 20,
      tokenBudget: Math.min(documentSize * 0.3, 8000), // 预算根据文档大小调整
      minImportanceScore: 0.4,
      enableSemanticCompression: true,
      keywords: ['技术', '参数', '指标', '性能'],
    };

    return this.contextManager.getCompressedContext(conversationId, config);
  }

  /**
   * 场景：客服对话（强调最近交互）
   */
  async getCustomerServiceContext(conversationId: string) {
    const config = {
      recentWindow: 8,
      tokenBudget: 2000,
      decayRate: 0.15, // 更快的时间衰减
      minImportanceScore: 0.5,
      enableSemanticCompression: false, // 客服对话要求精确，不压缩
    };

    return this.contextManager.getCompressedContext(conversationId, config);
  }

  /**
   * 场景：代码审查（保留所有代码片段）
   */
  async getCodeReviewContext(conversationId: string) {
    const config = {
      recentWindow: 15,
      tokenBudget: 6000,
      minImportanceScore: 0.3,
      enableSemanticCompression: true,
      keywords: ['代码', 'bug', '优化', '重构', 'function', 'class'],
    };

    return this.contextManager.getCompressedContext(conversationId, config);
  }
}

/**
 * 使用示例
 */
async function usageExample() {
  const orchestrator = new AgentOrchestratorWithCompression();
  const monitor = new ContextCompressionMonitor();

  // 执行 Agent
  const result = await orchestrator.executeAgent(
    'marketing_director_role_id',
    '分析这个技术的市场竞争力',
    'conversation-123',
    {
      scenarioType: 'tech_wrapping',
      techDocument: '800V高压平台技术...',
    }
  );

  // 记录统计
  if (result.metadata?.compressionStats) {
    monitor.recordCompression(result.metadata.compressionStats);
  }

  // 查看统计
  console.log('压缩统计:', monitor.getStats());
}
