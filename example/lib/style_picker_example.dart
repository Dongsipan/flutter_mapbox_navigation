import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

/// 插件内置样式选择器示例（新版：自动存储模式）
///
/// 展示新的简化 API：用户选择后自动存储，无需手动传参
class StylePickerExample extends StatefulWidget {
  const StylePickerExample({Key? key}) : super(key: key);

  @override
  State<StylePickerExample> createState() => _StylePickerExampleState();
}

class _StylePickerExampleState extends State<StylePickerExample> {
  String _currentStyle = 'standard';
  String _currentLightPreset = 'day';
  String _lightPresetMode = 'manual'; // manual 或 automatic
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStoredStyle();
  }

  /// 加载存储的样式设置
  Future<void> _loadStoredStyle() async {
    setState(() => _isLoading = true);

    try {
      final settings = await MapboxStylePicker.getStoredStyle();
      setState(() {
        _currentStyle = settings['mapStyle'] ?? 'standard';
        _currentLightPreset = settings['lightPreset'] ?? 'day';
        _lightPresetMode = settings['lightPresetMode'] ?? 'manual';
        _isLoading = false;
      });
    } catch (e) {
      print('加载样式失败: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 打开样式选择器
  Future<void> _openStylePicker() async {
    final saved = await MapboxStylePicker.show();

    if (saved) {
      // 重新加载显示最新设置
      _loadStoredStyle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 样式已保存！后续导航会自动使用'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 清除样式设置
  Future<void> _clearStyle() async {
    final cleared = await MapboxStylePicker.clearStoredStyle();

    if (cleared) {
      _loadStoredStyle();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 已恢复默认样式'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图样式设置'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 说明卡片
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // 当前配置
                  _buildCurrentSettings(),
                  const SizedBox(height: 24),

                  // 操作按钮
                  _buildActionButtons(),
                  const SizedBox(height: 32),

                  // 使用说明
                  _buildUsageInstructions(),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '新功能：自动存储',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '设置后自动保存，无需手动传参',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前配置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _buildSettingRow(
              icon: Icons.map,
              label: '地图样式',
              value: _getStyleDisplayName(_currentStyle),
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              icon: Icons.light_mode,
              label: 'Light Preset',
              value: _getLightPresetDisplayName(_currentLightPreset),
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              icon: Icons.autorenew,
              label: '根据日出日落自动调整',
              value: _lightPresetMode == 'automatic' ? '已启用' : '已禁用',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _openStylePicker,
          icon: const Icon(Icons.palette),
          label: const Text('打开样式选择器'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _clearStyle,
          icon: const Icon(Icons.refresh),
          label: const Text('恢复默认样式'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '使用说明',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              number: '1',
              text: '点击"打开样式选择器"按钮',
            ),
            _buildInstructionStep(
              number: '2',
              text: '在弹出的界面中选择你喜欢的样式',
            ),
            _buildInstructionStep(
              number: '3',
              text: '点击"应用"按钮保存设置',
            ),
            _buildInstructionStep(
              number: '4',
              text: '后续所有导航会自动使用你的设置',
              isLast: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '无需在代码中手动传递样式参数',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required String number,
    required String text,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStyleDisplayName(String style) {
    switch (style) {
      case 'standard':
        return 'Standard（标准）';
      case 'standardSatellite':
        return 'Standard Satellite（卫星）';
      case 'faded':
        return 'Faded（褪色）';
      case 'monochrome':
        return 'Monochrome（单色）';
      case 'light':
        return 'Light（浅色）';
      case 'dark':
        return 'Dark（深色）';
      case 'outdoors':
        return 'Outdoors（户外）';
      default:
        return style;
    }
  }

  String _getLightPresetDisplayName(String preset) {
    switch (preset) {
      case 'dawn':
        return '🌅 Dawn（黎明）';
      case 'day':
        return '☀️ Day（白天）';
      case 'dusk':
        return '🌇 Dusk（黄昏）';
      case 'night':
        return '🌙 Night（夜晚）';
      default:
        return preset;
    }
  }
}
