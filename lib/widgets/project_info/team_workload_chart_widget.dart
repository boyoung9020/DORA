import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../utils/avatar_color.dart';
import '../../widgets/glass_container.dart';

class MemberWorkload {
  final User member;
  final int count;
  const MemberWorkload({required this.member, required this.count});
}

class TeamWorkloadChart extends StatelessWidget {
  final List<MemberWorkload> memberWorkload;

  const TeamWorkloadChart({super.key, required this.memberWorkload});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxCount = memberWorkload.isEmpty
        ? 1
        : max(memberWorkload.map((m) => m.count).reduce(max), 1);

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 16,
      blur: 20,
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
      ],
      shadowBlurRadius: 8,
      shadowOffset: const Offset(0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('팀원별 작업 할당 현황',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface)),
          const SizedBox(height: 24),
          if (memberWorkload.isEmpty)
            SizedBox(
              height: 150,
              child: Center(
                child: Text('팀원이 없습니다',
                    style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5))),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: memberWorkload.map((mw) {
                  final barRatio = mw.count / maxCount;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${mw.count}건',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade600)),
                          const SizedBox(height: 4),
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: barRatio.clamp(0.05, 1.0),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade500,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                AvatarColor.getColorForUser(mw.member.username),
                            backgroundImage: mw.member.profileImageUrl != null
                                ? NetworkImage(mw.member.profileImageUrl!)
                                : null,
                            child: mw.member.profileImageUrl == null
                                ? Text(
                                    mw.member.username.isNotEmpty
                                        ? mw.member.username[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mw.member.username,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
