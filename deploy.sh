docker-compose down
git pull
docker build . -t dart_donation_bot
docker-compose up -d