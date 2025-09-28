// 文件: lib/widgets/account_card.dart
// (*** 这是完整、已修复的文件代码 ***)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:one_five_one_ten/models/account.dart';
import 'package:one_five_one_ten/utils/currency_formatter.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final Map<String, dynamic> accountPerformance;
  final bool isAmountVisible;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const AccountCard({
    super.key,
    required this.account,
    required this.accountPerformance,
    required this.isAmountVisible,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final percentFormat =
        NumberFormat.percentPattern('zh_CN')..maximumFractionDigits = 2;

    final totalValue = (accountPerformance['currentValue'] ?? 0.0) as double;
    final totalProfit = (accountPerformance['totalProfit'] ?? 0.0) as double;
    final profitRate = (accountPerformance['profitRate'] ?? 0.0) as double;
    final annualizedReturn =
        (accountPerformance['annualizedReturn'] ?? 0.0) as double;

    Color profitColor =
        totalProfit >= 0 ? Colors.red.shade400 : Colors.green.shade400;
    if (totalProfit == 0) {
      profitColor =
          Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    }

    String formatValue(dynamic value, String type) {
      if (!isAmountVisible) {
        return '***';
      }
      if (value is double) {
        switch (type) {
          case 'currency':
            return formatCurrency(value, account.currency);
          case 'percent':
            return percentFormat.format(value);
          default:
            return value.toString();
        }
      }
      return value.toString();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 账户名称行
              Row(
                children: [
                  CircleAvatar(
                    child: Text(account.name.isNotEmpty ? account.name.substring(0, 1) : '?'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      account.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              
              // (*** 关键修改：重构为与资产总览一致的 左/右 两列布局 ***)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧列：金额
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMetricItem(
                          '总资产',
                          formatValue(totalValue, 'currency'),
                          valueColor: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        _buildMetricItem(
                          '累计收益',
                          formatValue(totalProfit, 'currency'),
                          valueColor: isAmountVisible ? profitColor : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 右侧列：比率
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildMetricItem(
                          '收益率',
                          formatValue(profitRate, 'percent'),
                          valueColor: isAmountVisible ? profitColor : null,
                          alignment: CrossAxisAlignment.end,
                        ),
                        const SizedBox(height: 12),
                        _buildMetricItem(
                          '年化',
                          formatValue(annualizedReturn, 'percent'),
                          valueColor: isAmountVisible ? profitColor : null,
                          alignment: CrossAxisAlignment.end,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value,
      {Color? valueColor, CrossAxisAlignment? alignment}) {
    return Column(
      crossAxisAlignment: alignment ?? CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}