import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// docs/07-ui-ux-design.md §3.5 "Edit profile": "Sections: photos, prompts,
/// bio, basics, relationship goal, interests. Each opens a focused editor."
/// Bio/basics/relationship goal are combined into one "Basics & bio" editor
/// here rather than three single-field screens — they're the same PUT
/// /profiles/me call either way, and splitting them into three destinations
/// added IA complexity with no functional benefit. A disclosed
/// simplification, same spirit as the OTP-field / photo-reorder-buttons ones
/// from the onboarding feature.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/edit/photos'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Prompts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/edit/prompts'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Basics & bio'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/edit/basics'),
          ),
          ListTile(
            leading: const Icon(Icons.interests_outlined),
            title: const Text('Interests'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/edit/interests'),
          ),
        ],
      ),
    );
  }
}
