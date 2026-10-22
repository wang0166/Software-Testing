
import 'package:flutter/material.dart';

import '../../services/mock_auth_service.dart';

class HomePage extends StatelessWidget {
  final MockUser user;

  const HomePage({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('潘多拉'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.displayName}，你好！',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('欢迎使用潘多拉智能掌上日志系统'),
              const SizedBox(height: 28),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.edit_note),
                  title: Text('我的日志'),
                  subtitle: Text('日志填写与查看，待开发'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.comment_outlined),
                  title: Text('日志点评'),
                  subtitle: Text('上级点评与回复，待开发'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('统计看板'),
                  subtitle: Text('工作日志统计，待开发'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  '开发演示模式 · ${user.username}',
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}