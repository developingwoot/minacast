import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/models/podcast.dart';

class PodcastCard extends StatelessWidget {
  final Podcast podcast;
  final VoidCallback onTap;

  const PodcastCard({super.key, required this.podcast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: podcast.artworkUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (BuildContext ctx, String url) => Container(
            width: 56,
            height: 56,
            color: colors.surfaceContainerHighest,
            child: const Icon(Icons.podcasts, size: 28),
          ),
          errorWidget: (BuildContext ctx, String url, Object error) =>
              Container(
                width: 56,
                height: 56,
                color: colors.surfaceContainerHighest,
                child: const Icon(Icons.podcasts, size: 28),
              ),
        ),
      ),
      title: Text(
        podcast.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: text.bodyLarge,
      ),
      subtitle: podcast.author.isNotEmpty
          ? Text(
              podcast.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            )
          : null,
    );
  }
}
