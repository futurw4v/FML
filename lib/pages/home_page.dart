import 'package:flutter/material.dart';
import 'package:fmcl/models/storage/configs/paths_config.dart';
import 'package:fmcl/pages/home/management_page.dart';
import 'package:fmcl/pages/home/play_page.dart';
import 'package:fmcl/pages/home/version_page.dart';
import 'package:fmcl/storage/json_storage.dart';
import 'package:fmcl/utils/slide_page_route.dart';
import 'package:fmcl/widgets/app_card.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String _selectedAccountName = '未知账号';
  String _selectedGame = '未知版本';

  @override
  Widget build(BuildContext context) {
    final pathsStorage = context.watch<JsonStorage<PathsConfig>>();
    final pathsConfig = pathsStorage.data;

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ListView(
          children: [
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('当前文件夹'),
                subtitle: Text(pathsConfig.selectedFolderPath),
                leading: const Icon(Icons.view_list),
                onTap: () {
                  Navigator.push(
                    context,
                    SlidePageRoute(page: const VersionPage()),
                  );
                },
              ),
            ),
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('\n 版本设置 \n'),
                leading: const Icon(Icons.tune),
                onTap: () {
                  if (_selectedGame == '未选择版本') {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('请先选择游戏版本')));
                    return;
                  } else {
                    Navigator.push(
                      context,
                      SlidePageRoute(page: const ManagementPage()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedAccountName == '未选择账号') {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('请先选择账号')));
            return;
          }
          if (_selectedGame == '未选择版本') {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('请先选择游戏版本')));
            return;
          } else {
            Navigator.push(context, SlidePageRoute(page: const PlayPage()));
          }
        },
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
