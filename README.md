# dart_donation_bot
A simple bot that will monitor a Peercoin address for incoming Transactions (Donations) and mint events by connecting to a **Marisma** server.  
This bot will report those events to a given Discord channel.  
Transactions are persisted locally in a Hive database.

This bot **should** also work fine with all Bitcoin and Peercoin clones. Incoming Transactions from mining are so far not considered.

### Prerequisites
- docker-compose
- Marisma
- Discord API Token

### Get started
1. Clone this repo.
2. Create a *docker-compose.override.yml* file and set the environment variables accordingly.  
When starting for the first time, setting **SILENT_OPERATION=true** is recommended to avoid spam on initial build of the database.
3. run *./deploy.sh*
4. ??? 
5. You now have a donation bot. 
