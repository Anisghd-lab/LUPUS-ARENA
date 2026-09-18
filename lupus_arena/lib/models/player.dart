export 'player_model.dart';
import 'player_model.dart';

extension PlayerMapExt on Map<String, PlayerModel> {
  PlayerModel firstWhere(
    bool Function(PlayerModel) test, {
    PlayerModel Function()? orElse,
  }) {
    return values.firstWhere(test, orElse: orElse);
  }
}
