mkdir hive
docker-compose down
git pull
docker-compose build --no-cache dart_donation_bot
docker-compose up -d