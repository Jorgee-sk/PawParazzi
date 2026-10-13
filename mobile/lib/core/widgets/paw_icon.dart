import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Iconos exportados de Figma (trazo 1,8 px, colores ya aplicados según el componente).
abstract final class PawIcons {
  static const _i = 'assets/icons';
  static const navHome = '$_i/nav_home.svg';
  static const navHomeActive = '$_i/nav_home_active.svg';
  static const navCamera = '$_i/nav_camera.svg';
  static const navCameraActive = '$_i/nav_camera_active.svg';
  static const navHunt = '$_i/nav_hunt.svg';
  static const navHuntActive = '$_i/nav_hunt_active.svg';
  static const navGroups = '$_i/nav_groups.svg';
  static const navGroupsActive = '$_i/nav_groups_active.svg';
  static const navProfile = '$_i/nav_profile.svg';
  static const navProfileActive = '$_i/nav_profile_active.svg';
  static const arrowLeft = '$_i/arrow_left.svg';
  static const ellipsis = '$_i/ellipsis.svg';
  static const loader = '$_i/loader_circle.svg';
  static const heart = '$_i/heart_post.svg';
  static const messageCircle = '$_i/message_circle.svg';
  static const heartStreak = '$_i/heart_streak.svg';
  static const flame = '$_i/flame.svg';
  static const eyeOff = '$_i/eye_off.svg';
  static const circleCheck = '$_i/circle_check_selector.svg';
  static const circleCheckToast = '$_i/circle_check_toast.svg';
  static const check = '$_i/check_toast.svg';
  static const cloudOff = '$_i/cloud_off.svg';
  static const cameraOff = '$_i/camera_off.svg';
  static const camera = '$_i/camera.svg';
  static const users = '$_i/users_empty.svg';
  static const info = '$_i/info.svg';
  static const zap = '$_i/zap.svg';
  static const shutter = '$_i/capture_shutter.svg';
  static const avatarPending = '$_i/avatar_pending.svg';

  static const pawPrint32 = 'assets/brand/paw_print_32.svg';
  static const pawPrint22 = 'assets/brand/paw_print_22.svg';
  static const pawPrintWhite40 = 'assets/brand/paw_print_40_white.svg';
}

class PawIcon extends StatelessWidget {
  const PawIcon(this.asset, {super.key, this.size = 22, this.semanticLabel});

  final String asset;
  final double size;

  /// Etiqueta hablada; si es null el icono es decorativo.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
