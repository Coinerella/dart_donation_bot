module.exports = {
    apps: [
        {
            name: "PPC DonationBot",
            script: "./dart_donation_bot",
            watch: true,
            env: {
                "DISCORD_TOKEN": "YOUR_BOT_TOKEN_HERE",
            },
        }
    ]
}
