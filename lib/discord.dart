import 'dart:math';

import 'package:nyxx/nyxx.dart';

INyxxWebsocket? bot;
const generalChannelId = '390501055588335617';

void init(String discordToken) async {
  bot = NyxxFactory.createNyxxWebsocket(
      discordToken, GatewayIntents.allUnprivileged)
    ..registerPlugin(Logging())
    ..registerPlugin(CliIntegration())
    ..registerPlugin(IgnoreExceptions())
    ..connect();

  bot!.eventsWs.onReady.listen(
    (e) async {
      print("Ready!");
    },
  );
}

void sendDonationMessage(double amount) {
  List donationMessages = [
    'Someone has just donated $amount Peercoin to the foundation!\nThanks! Wanna donate? https://ppc.lol/fndtn',
    'Someone has just donated $amount Peercoin to the foundation!\nThanks! Every donations counts! https://ppc.lol/fndtn',
  ];
  sendMessage(donationMessages[Random().nextInt(donationMessages.length)]);
}

void sendMintMessage(double amount) {
  List mintMessages = [
    'The Peercoin Foundation has just minted $amount Peercoin!\nNice! Wanna know about the Foundation? https://ppc.lol/fndtn',
    'The Peercoin Foundation has just minted $amount Peercoin!\nDid you know the Foundation mints through something called Multisig? https://ppc.lol/multisig',
  ];
  sendMessage(mintMessages[Random().nextInt(mintMessages.length)]);
}

void sendMessage(String text) {
  bot!.httpEndpoints.sendMessage(
    Snowflake(generalChannelId),
    MessageBuilder.content(
      text,
    ),
  );
}

//TODO monitor reconnect / retry
