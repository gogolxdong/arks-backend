import std/[options, json, strutils, tables, times, strformat]
import pkg/[web3,chronos, stint, nimcrypto/keccak, web3/ethtypes]

#PlaceMakerOrder(uint256,address,bytes64,bool,bytes24,bytes128)
const placeMarketOrderSignature = "PlaceMakerOrder(uint256,address,uint64,bool,int24,uint128)" 
const swapSignature = "Swap(address,address,int256,int256,uint160,int24)"

echo &"{placeMarketOrderSignature}: 0x{toLowerAscii($keccak256.digest(placeMarketOrderSignature))}"
echo &"{swapSignature}: 0x{toLowerAscii($keccak256.digest(swapSignature))}"

contract(Grid):
    proc PlaceMakerOrder(orderId: indexed[UInt256], recipient:indexed[Address], bundleId: indexed[Uint64], zero:Bool, boundaryLower: Int24, amount: StUint[128]) {.event.}

contract(SwapRouterHub):
  proc Swap(sender: indexed[Address], recipient: indexed[Address], amount0: StInt[256],  amount1: StInt[256],  priceX96: Uint256, boundary: Int24) {.event.}

var swapRouterAddress = Address.fromHex("0xf4AE7E15B1012edceD8103510eeB560a9343AFd3")
var gridAddress = Address.fromHex("0xe8afd1fa3f91fa7387b0537bda5c525752efe821")

proc listen() {.async.} =
    var web3 = await newWeb3("ws://127.0.0.1:28545/")
    let accounts = await web3.provider.eth_accounts()
    echo "accounts: ", accounts
    web3.defaultAccount = accounts[0]
    echo "block: ", uint64(await web3.provider.eth_blockNumber())

    let notifFut = newFuture[void]()
    proc errorHandler(err: CatchableError) = echo "Error from MyEvent subscription: ", err.msg

    var logs = newJArray()
    proc eventHandler(j:JsonNode) {.gcsafe, raises: [Defect].} =
        try:
            if web3.subscriptions.len == 0:
                waitFor web3.close()
                web3 = waitFor newWeb3("http://127.0.0.1:28545")
                
            var orderId: UInt256
            echo decode(strip0xPrefix j["topics"][1].getStr, 0, orderId)
            echo "orderId:",orderId
            var recipient: Address
            discard decode(strip0xPrefix j["topics"][2].getStr, 0, recipient)
            echo "recipient:",recipient

            var bundleId: Uint64
            discard decode(strip0xPrefix j["topics"][3].getStr, 0, bundleId)
            echo "bundleId:",bundleId
            var inputData = strip0xPrefix j["data"].getStr
            var offset = 0
            var zero: Bool
            offset += decode(inputData, offset, zero)
            var boundaryLower: Int24
            offset += decode(inputData, offset, boundaryLower)
            var amount: StUint[128]
            offset += decode(inputData, offset, amount)
            # echo &"{now()}: orderId:{orderId} recipient:{recipient} bundleId:{bundleId} zero:{zero} boundaryLower:{boundaryLower.repr}, amount:{amount.repr}"
            # logs.add(j)
            writeFile("logs.json", $logs)
        except:
            echo getCurrentExceptionMsg()

    var options = %*{"fromBlock":"0"}
    let s = await web3.subscribeForLogs(options, eventHandler ,errorHandler) 
    await notifFut

    # proc handleSwap(sender: Address, recipient: Address, amount0: StInt[256],  amount1: StInt[256],  priceX96: Uint256, boundary: Int24){.raises: [Defect], gcsafe.}=
    #     try:
    #         echo &"sender:{sender} recipient:{recipient} amount0:{amount0} amount1:{amount1} priceX96:{priceX96}, boundary:{boundary}"
    #     except Exception as err:
    #         doAssert false, err.msg

    # let swapRouterHub = web3.contractSender(SwapRouterHub, swapRouterAddress)
    # let s = await swapRouterHub.subscribe(Swap, %*{"fromBlock": "latest"}, handleSwap, errorHandler) 
    # await notifFut

    proc handlePlaceMakerOrder(orderId: UInt256,recipient: Address, bundleId: Uint64, zero:Bool, boundaryLower: Int24, amount: StUint[128])=
        try:
            echo &"orderId:{orderId} recipient:{recipient} bundleId:{bundleId} zero:{zero} boundaryLower:{boundaryLower.repr}, amount:{amount.repr}"
        except Exception as err:
            doAssert false, err.msg
            
    # let grid = web3.contractSender(Grid, gridAddress)
    # let s = await grid.subscribe(PlaceMakerOrder, %*{"fromBlock": "latest"}, handlePlaceMakerOrder, errorHandler) 
    # await notifFut
    # await s.unsubscribe()
    # await web3.close()

import std/[random,options, json, parseutils, strutils, strformat, times, tables, sugar, sequtils, os, asynchttpserver]
import pkg/[ web3,chronos, nimcrypto, eth/keys, stint, puppy,  taskpools, presto ]
# import pkg/chronos except async, Future, FutureBase
import contracts

let headers = {"Content-type": "application/json",
    "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Method": "*",
    "Access-Control-Allow-Headers": "*"}.newHttpHeaders

type
  CustomKind* {.pure.} = enum
    Level1, Level2, Level3

  CustomType1* = object
    case kind*: CustomKind
    of Level1:
      level1*: int
    of Level2:
      level2*: string
    of Level3:
      level3*: seq[byte]

  GenericType*[T] = object
    data*: T

proc decodeString*(t: typedesc[string], value: string): RestResult[string] = ok(value)

proc testValidate*(pattern: string, value: string): int =
  let res =
    case pattern
    of "{address}":  0
    else:
      0
  res

template getRequired() {.dirty.} =
  useFlareMain:
    var level = waitFor flareMain.myLevel(Address.fromHex address).call()
  useSnapshot:
    var required = waitFor snapshot.refAmountRequiredPerDay(level).call()
  if usersJson[address].hasKey "required":
    for i in 0..<days:
      usersJson[address]["required"].add %(required.toInt)
    writeFile(file, $usersJson)
    var require = 0
    for num in usersJson[address]["required"]:
      require += num.getInt()
    return RestApiResponse.response($require)

var router = RestRouter.init(testValidate)
router.api(MethodGet,"/{address}") do (`address`:string) -> RestApiResponse:
  {.gcsafe.}:
    let request = %*{"method":"eth_getStorageAt","params":[snapshotAddress, "0xf", "latest"],"id":1,"jsonrpc":"2.0"}
    let response = post("https://rpc.tomoweb3.io",@[("Content-Type", "application/json")], $request)
    var responseBody = parseJson(response.body)["result"].getStr()
    var length = Uint256.fromHex(responseBody).toInt
    echo length
    var users = parseFile("users.json")
    if length > users.len:
      useSnapshot:
        for i in users.len..<length:
          var user = waitFor snapshot.userList(i.u256).call()
          users.add(%user)
    writeFile("users.json", $users)

    let address = `address`.get()
    var usersJson = newJObject()
    var timestamp = now().toTime().toUnix()
    var file = &"users/{address}.json"
    if fileExists(file):
        usersJson = parseFile(file)
        if usersJson.hasKey address:
          if usersJson[address].hasKey "timestamp":
            var lastTime = usersJson[address]["timestamp"].getInt
            var days = (timestamp - lastTime) div 86400
            if usersJson[address].hasKey "required":
              var require = 0
              for r in usersJson[address]["required"]:
                require += r.getInt()
              if days >= 1 :
                  useFlareMain:
                    var level = waitFor flareMain.myLevel(Address.fromHex address).call()
                  useSnapshot:
                    var required = waitFor snapshot.refAmountRequiredPerDay(level).call()
                  for i in 0..<days:
                    require += required.toInt
                    usersJson[address]["required"].add %(required.toInt)
                  writeFile(file, $usersJson)
              return RestApiResponse.response($require)
    else:
      useFlareMain:
        var level = waitFor flareMain.myLevel(Address.fromHex address).call()
      useSnapshot:
        var required = waitFor snapshot.refAmountRequiredPerDay(level).call()
      usersJson[address] = %*{"timestamp": timestamp, "required": [required.toInt]}
      writeFile(file, $usersJson)
      return RestApiResponse.response($required)

let request = %*{"method":"eth_getStorageAt","params":[snapshotAddress, "0xf", "latest"],"id":1,"jsonrpc":"2.0"}
let response = post("https://rpc.tomoweb3.io",@[("Content-Type", "application/json")], $request)
var result = parseJson(response.body)["result"].getStr()
var length = Uint256.fromHex(result).toInt
echo result, " ",length



proc main() =
  var tp = Taskpool.new()
  tp.spawn listen()
  let serverAddress = initTAddress("127.0.0.1:8081")
  var sres = RestServerRef.new(router, serverAddress)
  let server = sres.get()
  server.start()
  
  while server.state() == RestServerState.Running:
    runForever()

main()

