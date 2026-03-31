import 'package:flutter/material.dart';

import '../../../data/models/episode.dart';

class EpisodeListItem extends StatelessWidget {
  final Episode episode;
  final VoidCallback? onTap;
  final bool isDownloaded;
  final bool isDownloading;

  const EpisodeListItem({
    super.key,
    required this.episode,
    this.onTap,
    this.isDownloaded = false,
    this.isDownloading = false,
  });

  String _formatDuration(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatDate(int milliseconds) {
    final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).toLocal();
    final String month = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][dt.month];
    return '$month ${dt.day}, ${dt.year}';
  }

  Widget _buildTrailing(ColorScheme colors) {
    if (isDownloading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.outline),
      );
    }
    if (isDownloaded) {
      return Icon(Icons.offline_pin_outlined, color: colors.primary);
    }
    return Icon(Icons.play_arrow_outlined, color: colors.outline);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final String dateStr = episode.pubDate > 0
        ? _formatDate(episode.pubDate)
        : '';
    final String durationStr = episode.durationSeconds != null
        ? _formatDuration(episode.durationSeconds!)
        : '';
    final String meta = [
      dateStr,
      durationStr,
    ].where((String s) => s.isNotEmpty).join(' · ');

    return ListTile(
      onTap: onTap,
      title: Text(
        episode.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: text.bodyMedium,
      ),
      subtitle: meta.isNotEmpty
          ? Text(meta, style: text.bodySmall?.copyWith(color: colors.outline))
          : null,
      trailing: onTap != null ? _buildTrailing(colors) : null,
    );
  }
}
