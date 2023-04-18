import 'dart:io';
import 'dart:math';

import 'package:nyxx/nyxx.dart';

late INyxxWebsocket bot;
Map<String, String> env = Platform.environment;
final channelId = env['DISCORD_CHANNEL_ID'];

void init(String discordToken) async {
  bot = NyxxFactory.createNyxxWebsocket(
    discordToken,
    GatewayIntents.allUnprivileged,
  )
    ..registerPlugin(Logging())
    ..registerPlugin(CliIntegration())
    ..registerPlugin(IgnoreExceptions())
    ..connect();

  bot.eventsWs.onReady.listen(
    (e) async {
      print("Ready!");
    },
  );
}

void sendDonationMessage(double amount) {
  List donationMessages = [
    'Someone has just donated $amount Peercoin to the foundation!\nThanks! Wanna donate? https://ppc.lol/fndtn',
    'Someone has just donated $amount Peercoin to the foundation!\nThanks! Every donation counts! https://ppc.lol/fndtn',
    'Wooohoo - another $amount Peercoin donated to the foundation!\nWho is awesome? You are! https://ppc.lol/fndtn',
    'The Peercoin Foundation relies on your donations to operate.\nThat is why this $amount Peercoin Donation matters so much! https://ppc.lol/fndtn',
    'Another $amount Peercoin donated to the foundation!\nDonations like this help to further the project immensely. https://ppc.lol/fndtn',
  ];
  sendMessage(donationMessages[Random().nextInt(donationMessages.length)]);
}

void sendMintMessage(double amount) {
  List mintMessages = [
    'The Peercoin Foundation has just minted $amount Peercoin!\nNice! Wanna know about the Foundation? https://ppc.lol/fndtn',
    'Minting is fun. So much fun that the Foundation just minted $amount Peercoin!\nWanna know about the Foundation? https://ppc.lol/fndtn',
    'Minting is easy. So easy that the Foundation just minted $amount Peercoin!\nWanna know about the Foundation? https://ppc.lol/fndtn',
    'The Peercoin Foundation has just minted $amount Peercoin!\nDid you know the Foundation mints through something called Multisig? https://ppc.lol/multisig',
  ];
  sendMessage(mintMessages[Random().nextInt(mintMessages.length)]);
}

void sendMessage(String text) {
  if (env['SILENT_OPERATION'] == "true") return;

  bot.httpEndpoints.sendMessage(
    Snowflake(channelId),
    MessageBuilder.content(
      text,
    ),
  );
}
