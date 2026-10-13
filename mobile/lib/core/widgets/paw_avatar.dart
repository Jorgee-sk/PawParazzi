import 'package:flutter/material.dart';

import '../../features/profile/data/user_models.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'authed_image.dart';
import 'paw_icon.dart';

/// PawParazzi/UserAvatar: iniciales sobre lavanda (o foto si existe).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.imageUrl, this.size = 36});

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = size >= 56 ? PawText.avatarInitials28 : PawText.avatarInitials14;
    return Semantics(
      label: 'Avatar de $name',
      image: true,
      excludeSemantics: true,
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          color: PawColors.lavender,
          alignment: Alignment.center,
          child: imageUrl != null ? AuthedImage(imageUrl!) : Text(initialsOf(name), style: style),
        ),
      ),
    );
  }
}

/// PawParazzi/PetAvatar: siempre foto. Si la mascota aún no tiene foto, huella sobre lavanda.
class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.name, this.imageUrl, this.size = 40});

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Foto de $name',
      image: true,
      excludeSemantics: true,
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          color: PawColors.lavender,
          alignment: Alignment.center,
          child: imageUrl != null
              ? AuthedImage(imageUrl!)
              : PawIcon(PawIcons.pawPrint22, size: (size * 0.5).clamp(16, 40).toDouble()),
        ),
      ),
    );
  }
}
