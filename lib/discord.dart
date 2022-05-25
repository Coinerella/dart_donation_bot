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
  sendMessage(
    'Someone has just donated $amount Peercoin to the foundation! Thanks! Wanna donate? ppc.lol/fndtn',
  );
}

void sendMintMessage(double amount) {
  sendMessage(
    'The Peercoin Foundation has just minted $amount Peercoin! Nice! Wanna know about the Foundation? ppc.lol/fndtn',
  );
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