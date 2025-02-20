# Event Stream app for Herd Actions

## Notion site with the report: https://autumn-sidecar-877.notion.site/Exercise-Event-Stream-for-Herd-Actions-15ef0183ba1580608e64fe6728e277e2

## Live demo deployed into Fly.io: https://demotruherd.fly.dev/


- Rails version 8.0.1 
- Ruby version 3.3.4


# 1. Pre-requisites
In order to run locally you must install **Docker** and **Devcontainers**
- **Docker** https://www.docker.com/
- **Devcontainers** https://github.com/devcontainers/cli 


    Using NPM:
    ```bash
      npm install -g @devcontainers/cli or with NPX:  npx install -g @devcontainers/cli 
    ```
    using NPX:
    ```bash
      npx install -g @devcontainers/cli 
    ```   

# 2. Build the container:


```bash
bin/build_container
```

# 3. Run the seeds

```bash
bin/rails db:seed
```


# 4. Run the container in a local enviroment:

```bash
bin/dev
```


