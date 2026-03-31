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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (podcast.author.isNotEmpty)
            Text(
              podcast.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          if (podcast.averageUserRating != null &&
              podcast.userRatingCount != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: _RatingRow(
                rating: podcast.averageUserRating!,
                count: podcast.userRatingCount!,
                colors: colors,
                text: text,
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.count,
    required this.colors,
    required this.text,
  });

  final double rating;
  final int count;
  final ColorScheme colors;
  final TextTheme text;

  String _formatCount(int n) {
    if (n >= 1000) {
      final double k = n / 1000.0;
      return '(${k.toStringAsFixed(k >= 10 ? 0 : 1)}K)';
    }
    return '($n)';
  }

  @override
  Widget build(BuildContext context) {
    final int fullStars = rating.floor();
    final bool halfStar = (rating - fullStars) >= 0.5;
    final int emptyStars = 5 - fullStars - (halfStar ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < fullStars; i++)
          Icon(Icons.star, size: 12, color: colors.primary),
        if (halfStar)
          Icon(Icons.star_half, size: 12, color: colors.primary),
        for (int i = 0; i < emptyStars; i++)
          Icon(Icons.star_border, size: 12, color: colors.outline),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: text.bodySmall?.copyWith(color: colors.outline),
        ),
      ],
    );
  }
}
