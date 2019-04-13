import asynchttpserver, asyncdispatch, parsecfg, os, osproc, json, httpclient, strformat

var cfg = loadConfig(getEnv("CONFIG", "configs/config.ini"))
var secrets = loadConfig(cfg.getSectionValue("bot", "secrets"))

var server = newAsyncHttpServer()
var client = newAsyncHttpClient()

client.headers = newHttpHeaders({ "Content-Type": "application/json" })

type
    Author = object
        name: string
        email: string
        username: string
        
    Commit = object
        id: string
        message: string
        author: Author

    User = object
        login: string
        url: string
        avatar_url: string

    Repository = object
        name: string
        full_name: string
        url: string
        owner: User

    TreeLike = object
        `ref`: string
        sha: string
        repo: Repository
        user: User

    PullRequest = object
        title: string
        body: string
        html_url: string
        head: TreeLike
        created_at: string

    PullRequestBody = object
        action: string
        number: int
        pull_request: PullRequest
        
    PushBody = object
        `ref`: string
        after: string
        commits: seq[Commit]

let webhookUrl = secrets.getSectionValue("secrets", "discord_webhook")

proc ensure[T](fut: Future[T]): Future[T] =
    return fut

proc waitForProcess(pc: Process): Future[void] =
    var fut = newFuture[void]("waitForProcess")
    addProcess(pc.processID, proc (fd: AsyncFD): bool = fut.complete)
    
    return ensure(fut)

proc handler(req: Request) {.async gcsafe.} =
    if req.reqMethod != HttpPost or not req.headers.hasKey("X-GitHub-Event"):
        await req.respond(Http405, "405 Method Not Allowed")
        return

    var event: string = req.headers["X-GitHub-Event"]
    var body = parseJson(req.body)

    if event == "push":
        var push = to(body, PushBody)
        var pc = startProcess("git", workingDir = "/srv/thonkbot", args = ["pull"])

        await waitForProcess(pc)

        var body = %*{
            "content": &"Pulled thonkbot commit {push.after}"
        }

        discard await client.request(webhookUrl, httpMethod = HttpPost, body = $body)
    elif event == "pull_request":
        var pr = to(body, PullRequestBody)

        var embed = %*{
            "title": &"(#{pr.number}) {pr.pull_request.title}",
            "description": pr.pull_request.body,
            "url": pr.pull_request.html_url,
            "author": {
                "name": &"New pull request in {pr.pull_request.head.repo.full_name}"
            },
            "timestamp": pr.pull_request.created_at
        }

        var body = %*{
            "embeds": @[embed]
        }

        discard await client.request(webhookUrl, httpMethod = HttpPost, body = $body)

    await req.respond(Http200, "OK")

waitFor server.serve(Port(5010), handler)
