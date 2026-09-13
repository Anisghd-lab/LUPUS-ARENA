import 'package:flutter/material.dart';

/// Références aux ressources visuelles officielles issues de la génération Stitch.
/// Tente de charger les images locales en priorité (assets/images/...),
/// avec fallback automatique sur les URLs hébergées en haute définition.
class LupusAssets {
  static const String villageNightBgUrl =
      'https://lh3.googleusercontent.com/aida/AEtjO1VLU-7dEtLiciSxE9WCO-H3XbPVMrQ7vSCVwDcc3L_58zWH96UckrkDtc_KRSTCdFxH0GkH7FsU7BlrvIjlne1mlQfa70B4ikGQ-D9FHOGhwa7SUxSpuKZQtgGUk6IarImvbWC8ryKcGzqiM3Q4L95eFGbcaTOnD4y721apGQDyYo6Vjvjtd_aKQ9MMV8_4jl30vFrp5ksk_KK04JEArUfRzpRccaGh_YJm4lQu3SmHFhZIyGnqfR1QdQY';

  static const String wolfSealUrl =
      'https://lh3.googleusercontent.com/aida/AEtjO1XxsqyMQQ0dm_oZGy9LIuAaqn0OSl-sKCKS4kQRFn-rD9oDYNb_by64mIXCAv5LoNswBPn5aHtjVpfPJWO5kC9pSjkZIDp-Ziy1izTdt08o_rzAsXZ5FOneq8be_epHwHoXUdgsB6PYDj9iK_C1yErktt_UkgBYoKT5oBr1XPBJN8Lc34VyZ79tz6c8A-PtW-gMRXvTHWoISelA2nvxGlkZ75OYfSv8whbrXONV9cc40vYly0zg7dgtkw';

  static const String tableNuitMockupUrl =
      'https://lh3.googleusercontent.com/aida/AEtjO1U-YPASGFap0SkMQqeju4P6z6X8-Fx7I-kRcC_tTu6j3whleWxMg_UYkg85Wm2afVt8D2BZCkG0Quowxg-kFoh7LFSZmBUnxPWPpGtFD-FxveMzaD4DuMdjmz-jCmri9iSfi-7S-8CaO2hUftJVOb6f1FRzH0DLHTyc5zN_TMq3shY61DDoXbMsP1pRByPUGJXN6P697kTUjFVEELSwdu4Ws495q3H5-pfta7MPm9yzzvaX2xYy_YgRIZg';

  static const String villageNightBgAsset =
      'assets/images/village_background.png';
  static const String villageNightBgAssetFallback =
      'village_background.png';
  static const String wolfSealAsset = 'assets/images/lupus_seal.png';
  static const String tableNuitMockupAsset =
      'assets/images/table_nuit_mockup.png';

  /// Widget intelligent chargeant l'asset local avec bascule gracieuse sur l'URL hébergée
  static Widget adaptiveImage({
    required String assetPath,
    required String networkUrl,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
    double? width,
    double? height,
    Widget? placeholder,
  }) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          villageNightBgAssetFallback,
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          errorBuilder: (context, error2, stackTrace2) {
            return Image.network(
              networkUrl,
              width: width,
              height: height,
              fit: fit,
              alignment: alignment,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return placeholder ??
                    Container(
                      width: width,
                      height: height,
                      color: const Color(0xFF070B1D),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Color(0xFF9D4EDD)),
                          ),
                        ),
                      ),
                    );
              },
              errorBuilder: (context, error3, stackTrace3) {
                return placeholder ??
                    Container(
                      width: width,
                      height: height,
                      color: const Color(0xFF070B1D),
                    );
              },
            );
          },
        );
      },
    );
  }
}
