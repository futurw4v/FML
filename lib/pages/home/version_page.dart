import 'package:flutter/material.dart';
import 'package:fmcl/constants.dart';
import 'package:fmcl/models/storage/configs/paths_config.dart';
import 'package:fmcl/storage/extensions/paths_storage_ext.dart';
import 'package:fmcl/storage/json_storage.dart';
import 'package:fmcl/widgets/app_card.dart';
import 'package:provider/provider.dart';

class VersionPage extends StatefulWidget {
  const VersionPage({super.key});

  @override
  VersionPageState createState() => VersionPageState();
}

class VersionPageState extends State<VersionPage> {
  @override
  Widget build(BuildContext context) {
    final pathsStorage = context.watch<JsonStorage<PathsConfig>>();
    final pathsConfig = pathsStorage.data;
    final dotMinecraftFolders = pathsConfig.paths;

    return Scaffold(
      appBar: AppBar(title: const Text('版本文件夹管理')),
      body: dotMinecraftFolders.isEmpty
          ? const Center(child: Text('暂无版本文件夹'))
          : ListView.builder(
              padding: const EdgeInsets.all(kDefaultPadding),
              itemCount: dotMinecraftFolders.length,
              itemBuilder: (context, index) {
                final folder = dotMinecraftFolders[index];
                final isSelected =
                    folder.path == pathsConfig.selectedFolderPath;

                return AppCard(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: isSelected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: ListTile(
                    title: Text(folder.name.isEmpty ? '游戏文件夹' : folder.name),
                    subtitle: Text(folder.path),
                    leading: const Icon(Icons.folder),
                    onTap: () {
                      pathsStorage.selectPath(folder.path);
                    },
                  ),
                );
              },
            ),
    );
  }
}
