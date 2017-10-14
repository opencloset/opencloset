#!/bin/sh
env | grep MOJO | sed 's/^\(.*\)$/export \1/g' > /home/opencloset/.env.sh
env | grep PATH | sed 's/^\(.*\)$/export \1/g' >> /home/opencloset/.env.sh
env | grep OPENCLOSET | sed 's/^\(.*\)$/export \1/g' >> /home/opencloset/.env.sh
chmod o+x /home/opencloset/.env.sh

# Run the command on container startup
cron -f
