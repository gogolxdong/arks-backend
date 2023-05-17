import std/[options, json, strutils, tables, times, strformat]
import std/[random,options, json, parseutils, strutils, strformat, times, tables, sugar, sequtils, os, asynchttpserver]
import pkg/[ web3,chronos, nimcrypto, eth/keys, stint, puppy,  taskpools, presto ]
import pkg/[web3,chronos, stint, nimcrypto/keccak, web3/ethtypes]

const buySignature = "Buy(address executor, uint256 nftType,  uint256 tokenId,uint256  nftTotalValue, uint256 buyRewardsAmount,uint256 time)"
const BNPLSignature = "BNPL(address executor, uint256 nftType, uint256 tokenId,uint256 nftTotalValue, uint256 downPayment,uint256 totalInterest,uint256 planTermLength,uint256 planRewardsAmount,uint256 time)"
const repaySignature = "Repay(address executor, uint256 nftType, uint256 tokenId,uint256 planTermLength, uint256 planTermProgress, uint256 repayTotalValue,  uint256 repayInterestValye,uint256 dueThisTerm,uint256 time)"
const redeemSignature = "Redeem(address executor, uint256 nftType, uint256 tokenId,uint256 nftTotalValue, uint256 redeemFee, uint256 receivedValue,  uint256 requestTime,uint256 time)"
const liquidationSignature = "Liquidation(address executor, uint256 nftType, uint256 tokenId,uint256 nftTotalValue, uint256 totalLoanValue, uint256 unpaidLoanValue,  uint256 liquidationValue,  uint256 dueThisTerm,uint256 time)"
const borrowSignature = "Borrow(address executor, uint256 nftType, uint256 tokenId,uint256 nftTotalValue, uint256 borrowValue, uint256 totalInterest,uint256 planTermLength,uint256 planRewardsAmount,uint256 time)"
const stakeSignature = "Stake(address executor, uint256 nftType, uint256 tokenId,uint256 nftTotalValue, uint256 stakePoolId, uint256 time)"
const unstakeSignature = "Unstake(address executor, uint256 nftType, uint256  tokenId,uint256 nftTotalValue, uint256 stakePoolId, uint256 time)"
const finishPlanSignature = "FinishPlan(address executor, uint256 nftType, uint256 tokenId,uint256 nftTotalValue, uint256 totalInterest,uint256 planTermLength,uint256 planRewardsAmount,uint256 time)"

const buySignatureHash = &"0x{toLowerAscii($keccak256.digest(buySignature))}"
const BNPLSignatureHash = &"0x{toLowerAscii($keccak256.digest(BNPLSignature))}"
const repaySignatureHash = &"0x{toLowerAscii($keccak256.digest(repaySignature))}"
const redeemSignatureHash = &"0x{toLowerAscii($keccak256.digest(redeemSignature))}"
const liquidationSignatureHash = &"0x{toLowerAscii($keccak256.digest(liquidationSignature))}"
const borrowSignatureHash = &"0x{toLowerAscii($keccak256.digest(borrowSignature))}"
const stakeSignatureHash = &"0x{toLowerAscii($keccak256.digest(stakeSignature))}"
const unstakeSignatureHash = &"0x{toLowerAscii($keccak256.digest(unstakeSignature))}"
const finishPlanSignatureHash = &"0x{toLowerAscii($keccak256.digest(finishPlanSignature))}"

echo &"{buySignature}: {buySignatureHash}"
echo &"{BNPLSignature}: 0x{toLowerAscii($keccak256.digest(BNPLSignature))}"


contract(Nouns):
    proc Buy( executor: indexed[Address], nftType: indexed[Uint256],  tokenId: indexed[Uint256],   nftTotalValue:Uint256, buyRewardsAmount:Uint256 ,time:Uint256 ) {.event.}
    proc BNPL( executor: indexed[Address],  nftType: indexed[Uint256],  tokenId:indexed[Uint256],  nftTotalValue:Uint256,  downPayment:Uint256, totalInterest:Uint256, planTermLength:Uint256, planRewardsAmount:Uint256, time:Uint256) {.event.}
    proc Repay( executor:indexed[Address],  nftType:indexed[Uint256], tokenId: indexed[Uint256],  planTermLength: Uint256, planTermProgress:Uint256 ,  repayTotalValue:Uint256, repayInterestValye:Uint256, dueThisTerm:Uint256, time:Uint256) {.event.}
    proc Redeem( executor:indexed[Address], nftType: indexed[Uint256], tokenId: indexed[Uint256],  nftTotalValue:Uint256,  redeemFee:Uint256,  receivedValue:Uint256,   requestTime:Uint256, time:Uint256) {.event.}
    proc Liquidation( executor:indexed[Address],  nftType:indexed[Uint256],  tokenId:indexed[Uint256],  nftTotalValue:Uint256,  totalLoanValue:Uint256,  unpaidLoanValue:Uint256,   liquidationValue:Uint256,   dueThisTerm:Uint256, time:Uint256) {.event.}
    proc Borrow( executor:indexed[Address],  nftType:indexed[Uint256],  tokenId:indexed[Uint256],  nftTotalValue:Uint256,  borrowValue:Uint256,  totalInterest:Uint256, planTermLength:Uint256, planRewardsAmount:Uint256, time:Uint256) {.event.}
    proc Stake(executor:indexed[Address], nftType: indexed[Uint256],  tokenId:indexed[Uint256],  nftTotalValue:Uint256,  stakePoolId:Uint256,  time:Uint256) {.event.}
    proc Unstake(executor:indexed[Address], nftType: indexed[Uint256],  tokenId:indexed[Uint256],  nftTotalValue:Uint256,  stakePoolId:Uint256,  time:Uint256) {.event.}
    proc FinishPlan(executor:indexed[Address], nftType: indexed[Uint256],  tokenId:indexed[Uint256],  nftTotalValue:Uint256,  totalInterest:Uint256, planTermLength:Uint256, planRewardsAmount:Uint256, time:Uint256) {.event.}

var nounsBNPL = Address.fromHex("")

template parseCommonValue() {.dirty.} =
  var executor: Address
  echo decode(strip0xPrefix j["topics"][1].getStr, 0, executor)
  echo "executor:",executor

  var nftType: Uint256
  discard decode(strip0xPrefix j["topics"][2].getStr, 0, nftType)
  echo "nftType:",nftType

  var tokenId: Uint256
  discard decode(strip0xPrefix j["topics"][3].getStr, 0, tokenId)
  echo "tokenId:",tokenId

  var inputData = strip0xPrefix j["data"].getStr
  var offset = 0

  var nftTotalValue: Uint256
  offset += decode(inputData, offset, nftTotalValue)

proc parseBuyEvent(j:JsonNode) =
  parseCommonValue()

  var buyRewardsAmount: Uint256
  offset += decode(inputData, offset, buyRewardsAmount)

  var time: Uint256
  offset += decode(inputData, offset, time)

proc parseBNPLEvent(j:JsonNode) =
  parseCommonValue()

  var downPayment: Uint256
  offset += decode(inputData, offset, downPayment)

  var totalInterest: Uint256
  offset += decode(inputData, offset, totalInterest)

  var time: Uint256
  offset += decode(inputData, offset, time)

proc parseRepayEvent(j:JsonNode) =
  var executor: Address
  echo decode(strip0xPrefix j["topics"][1].getStr, 0, executor)
  echo "executor:",executor

  var nftType: Uint256
  discard decode(strip0xPrefix j["topics"][2].getStr, 0, nftType)
  echo "nftType:",nftType

  var tokenId: Uint256
  discard decode(strip0xPrefix j["topics"][3].getStr, 0, tokenId)
  echo "tokenId:",tokenId

  var inputData = strip0xPrefix j["data"].getStr
  var offset = 0

  var planTermLength: Uint256
  offset += decode(inputData, offset, planTermLength)

  var planTermProgress: Uint256
  offset += decode(inputData, offset, planTermProgress)

  var repayTotalValue: Uint256
  offset += decode(inputData, offset, repayTotalValue)

  var repayInterestValye: Uint256
  offset += decode(inputData, offset, repayInterestValye)

  var dueThisTerm: Uint256
  offset += decode(inputData, offset, dueThisTerm)

  var time: Uint256
  offset += decode(inputData, offset, time)

proc parseRedeemEvent(j:JsonNode) =
  parseCommonValue()

  var redeemFee: Uint256
  offset += decode(inputData, offset, redeemFee)

  var receivedValue: Uint256
  offset += decode(inputData, offset, receivedValue)

  var requestTime: Uint256
  offset += decode(inputData, offset, requestTime)

  var time: Uint256
  offset += decode(inputData, offset, time)

proc parseLiquidationEvent(j:JsonNode) =
  parseCommonValue()

  var totalLoanValue:Uint256
  offset += decode(inputData, offset, totalLoanValue)

  var unpaidLoanValue:Uint256
  offset += decode(inputData, offset, unpaidLoanValue)

  var liquidationValue:Uint256
  offset += decode(inputData, offset, liquidationValue)

  var dueThisTerm:Uint256
  offset += decode(inputData, offset, dueThisTerm)

  var time: Uint256
  offset += decode(inputData, offset, time)

proc parseBorrowEvent(j:JsonNode) = 
  parseCommonValue()

  var borrowValue:Uint256
  offset += decode(inputData, offset, borrowValue)

  var totalInterest:Uint256
  offset += decode(inputData, offset, totalInterest)

  var planTermLength:Uint256
  offset += decode(inputData, offset, planTermLength)

  var planRewardsAmount:Uint256
  offset += decode(inputData, offset, planRewardsAmount)

  var time: Uint256
  offset += decode(inputData, offset, time)

proc parseStakeEvent(j:JsonNode) = 
  parseCommonValue()

  var stakePoolId:Uint256
  offset += decode(inputData, offset, stakePoolId)

  var time: Uint256
  offset += decode(inputData, offset, time)

proc parseUnstakeEvent(j:JsonNode) = 
  parseCommonValue()

  var stakePoolId:Uint256
  offset += decode(inputData, offset, stakePoolId)

  var time: Uint256
  offset += decode(inputData, offset, time)

proc parseFinishPlanEvent(j:JsonNode) = 
  parseCommonValue()

  var totalInterest:Uint256
  offset += decode(inputData, offset, totalInterest)

  var planTermLength:Uint256
  offset += decode(inputData, offset, planTermLength)

  var planRewardsAmount:Uint256
  offset += decode(inputData, offset, planRewardsAmount)

  var time: Uint256
  offset += decode(inputData, offset, time)


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
            
            case j["topics"][0].getStr
            of buySignatureHash: parseBuyEvent(j)
            of BNPLSignatureHash: parseBNPLEvent(j)
            of repaySignatureHash: parseRepayEvent(j)
            of redeemSignatureHash: parseRedeemEvent(j)
            of liquidationSignatureHash: parseLiquidationEvent(j)
            of borrowSignatureHash: parseBorrowEvent(j)
            of stakeSignatureHash: parseStakeEvent(j)
            of unstakeSignatureHash: parseUnstakeEvent(j)
            of finishPlanSignatureHash: parseFinishPlanEvent(j)
            
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
      return RestApiResponse.response("")

proc main() =
  var tp = Taskpool.new()
  discard tp.spawn listen()
  let serverAddress = initTAddress("127.0.0.1:8081")
  var sres = RestServerRef.new(router, serverAddress)
  let server = sres.get()
  server.start()
  
  while server.state() == RestServerState.Running:
    runForever()

main()

