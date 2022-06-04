import 'dart:io';

import 'package:dart_donation_bot/electrum_connection.dart' as connection;
import 'package:dart_donation_bot/discord.dart' as discord;
import 'package:hive/hive.dart';

void main(List<String> arguments) async {
  //check for discord token in env
  Map<String, String> env = Platform.environment;

  if (env.containsKey("DISCORD_API_TOKEN")) {
    Hive.init('/app/hive/');
    await connection.connect();
    discord.init(env["DISCORD_API_TOKEN"]!);
  } else {
    throw Exception("DISCORD_API_TOKEN needs to be in environment");
  }
}
