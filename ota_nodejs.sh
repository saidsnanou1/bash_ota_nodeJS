#!/bin/bash


PROJECT_DIR="$HOME/MEDIOT_133_EDGE_NEST"
JSON_URL="https://raw.githubusercontent.com/saidsnanou1/https-ota-s/master/firmware.json"

RETRY_INTERVAL=60  
MAX_RETRIES=3  
while true; do
    # Check internet connection before fetching JSON
    if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
        echo "Internet connection detected."

        # Fetch the JSON file using curl
        JSON_CONTENT=$(curl -s $JSON_URL)

        if [[ $? -ne 0 ]]; then
            echo "Failed to fetch JSON file. Retrying in $RETRY_INTERVAL seconds..."
            sleep $RETRY_INTERVAL
            continue
        fi


        # Parse the JSON content to get the version using jq
        NEW_VERSION=$(echo "$JSON_CONTENT" | jq -r '.version')
        CURRENT_VERSION=$(cat "$PROJECT_DIR/firmware.json" | jq -r '.version')

        echo "Fetched Version: $NEW_VERSION"
        echo "Current Version: $CURRENT_VERSION"

        # Change directory to project directory
        cd "$PROJECT_DIR" || exit

        # Compare versions
        if [[ "$NEW_VERSION" > "$CURRENT_VERSION" ]]; then
            echo "New version available: $NEW_VERSION"

            for ((i=1; i<=MAX_RETRIES; i++)); do
                #git pull 
                git pull 
                if [[ $? -ne 0 ]]; then
                    echo "git pull failed. Attempt $i of $MAX_RETRIES. Retrying in $RETRY_INTERVAL seconds..."
                    sleep 10
                    if [[ $i -eq $MAX_RETRIES ]]; then
                        echo "git pull failed after $MAX_RETRIES attempts. Skipping this update cycle."
                        break
                    fi
                    continue
                fi

                npm install
                if [[ $? -ne 0 ]]; then
                    echo "npm install failed. Attempt $i of $MAX_RETRIES. Retrying in $RETRY_INTERVAL seconds..."
                    sleep 10
                    if [[ $i -eq $MAX_RETRIES ]]; then
                        echo "npm install failed after $MAX_RETRIES attempts. Skipping this update cycle."
                        sudo rm -rf node_modules/
                        break
                    fi
                    continue
                fi

                npm run build
                if [[ $? -ne 0 ]]; then
                    echo "npm run build failed. Attempt $i of $MAX_RETRIES. Retrying in $RETRY_INTERVAL seconds..."
                    sleep 10
                    if [[ $i -eq $MAX_RETRIES ]]; then
                        echo "npm run build failed after $MAX_RETRIES attempts. Skipping this update cycle."
                        break
                    fi
                    continue
                fi

                pm2 restart 0
                if [[ $? -ne 0 ]]; then
                    echo "pm2 restart failed. Attempt $i of $MAX_RETRIES. Retrying in $RETRY_INTERVAL seconds..."
                    sleep 10
                    if [[ $i -eq $MAX_RETRIES ]]; then
                        echo "pm2 restart failed after $MAX_RETRIES attempts. Skipping this update cycle."
                        break
                    fi
                    continue
                fi

                echo "Update completed successfully."
                echo "$(echo "$JSON_CONTENT" | jq ".version = \"$NEW_VERSION\"")" > firmware.json
                break
        done

        else
            echo "Current version $CURRENT_VERSION is up to date."
        fi
    else
        echo "No internet connection. Retrying in 10 seconds..."
    fi

    # Wait for 10 seconds before checking again
    sleep 10
done
