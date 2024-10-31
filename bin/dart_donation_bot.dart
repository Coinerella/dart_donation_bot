import 'dart:io';

import 'package:dart_donation_bot/discord.dart' as discord;
import 'package:dart_donation_bot/marisma_connection.dart';
import 'package:hive/hive.dart';

void main(List<String> arguments) async {
  //check for settings in env
  Map<String, String> env = Platform.environment;
  List<String> requiredEnvs = [
    "DISCORD_API_TOKEN",
    "DISCORD_CHANNEL_ID",
    "DONATION_ADDRESS",
    "MARISMA_SERVER_HOST",
    "MARISMA_SERVER_PORT",
    "SEND_MINT_MESSAGES",
  ];

  for (var requiredEnv in requiredEnvs) {
    if (!env.containsKey(requiredEnv)) {
      throw Exception("$requiredEnv needs to be in environment");
    } else if (env[requiredEnv]!.isEmpty) {
      throw Exception("$requiredEnv needs to have a value");
    }
  }

  Hive.init(
    env["LOCAL_TESTING"] == "true" ? 'hive' : '/app/hive/',
  );

  //init discord
  await discord.init(env["DISCORD_API_TOKEN"]!);

  //open MarismaConnection
  MarismaConnection();
}
