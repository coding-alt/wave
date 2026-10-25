# 小旋风收音机 接口文档

> 逆向自 `小旋风-v1.2.5.apk`（`com.xiaoxuanfeng.ILoveRadio`，Flutter / Dart 3.10.0）。
> 下列接口均已在 2026-10 实测跑通，并通过 `api/client.py` 复现。

## 0. 通用约定

服务端地址：`http://49.232.234.212`（纯 HTTP，无 TLS）

- 所有业务接口均为 **POST**
- 请求体是 **`application/x-www-form-urlencoded`**，只有一个字段 `sign`
- `sign` = `base64(AES(JSON(params)))`

```
AES 参数
  algorithm : AES-128
  mode      : ECB
  padding   : PKCS7
  key       : "ILOVERADIO666666"      (16 bytes, UTF-8)
  iv        : "0000000000000000"      (ECB 模式不使用)
  output    : 标准 Base64（非 URL-safe）
```

### 公共参数（每个请求都必须带）

| 字段 | 类型 | 说明 |
|---|---|---|
| `imei` | string | 设备标识，任意 UUID 即可 |
| `uid` | string | 用户标识，未登录时同 `imei` |
| `device` | string | 固定 `"2"`（安卓） |
| `qd` | string | 渠道号，固定 `"2002"` |
| `version` | string | App 版本，如 `"1.2.5"` |
| `model` | string | 固定 `"Andriod"`（原文拼写如此） |
| `channelid` | string | 固定 `"Andriod"` |

登录后额外携带 `u_phone`（手机号）。

### 请求示例

```http
POST /radio/getAllCategory HTTP/1.1
Host: 49.232.234.212
Accept: application/json;charset=UTF-8
Content-Type: application/x-www-form-urlencoded; charset=utf-8

sign=vQ0mO...（省略）
```

### 响应结构

```json
{ "msg": "成功", "code": "200", "data": "<base64(AES(json))>" }
```

- `data` 与请求用同一套密钥/模式加密，解密后才是真实 JSON
- 解密失败或参数异常时，`data` 会退化为空对象 `{}`

### 错误码

| code | 含义 |
|---|---|
| `200` | 成功 |
| `400` | 请求处理异常（常见于 `sign` 解密失败 / 缺少必填参数） |
| `500` | 请求方式有误（用了 GET） |
| `501` | 请求路径不存在 |

---

## 1. 电台分类

`POST /radio/getAllCategory`

参数：无（仅公共参数）

响应 `data`：

```json
{
  "provinces": [
    { "pid": 109991, "title": "香港" },
    { "pid": 109992, "title": "澳门" },
    { "pid": 109993, "title": "台湾" },
    { "pid": 110000, "title": "北京" },
    { "pid": 120000, "title": "天津" },
    { "pid": 130000, "title": "河北" }
  ],
  "cates": [
    { "pid": 420, "title": "伴音" },
    { "pid": 433, "title": "新闻台" },
    { "pid": 442, "title": "音乐台" },
    { "pid": 429, "title": "交通台" },
    { "pid": 430, "title": "体育台" },
    { "pid": 439, "title": "经济台" },
    { "pid": 432, "title": "文艺台" },
    { "pid": 436, "title": "曲艺台" },
    { "pid": 434, "title": "方言台" },
    { "pid": 431, "title": "外语台" },
    { "pid": 438, "title": "生活台" },
    { "pid": 441, "title": "都市台" },
    { "pid": 435, "title": "旅游台" },
    { "pid": 450, "title": "Music" }
  ],
  "audios": ["相声", "财经", "英语", "戏曲"]
}
```

- `provinces`：34 个（含港澳台），`pid` 即行政区划码
- `cates`：14 个电台类型
- `audios`：音频分类（当前 App 未使用）

---

## 2. 电台列表

`POST /radio/getRadios`

参数（二选一，同时传则取交集）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `provinceId` | string | 省份 id，如 `"110000"` |
| `cateId` | string | 类型 id，如 `"433"` |

响应 `data`：

```json
{
  "province_id": "110000",
  "cateId": "",
  "radios": [ { /* 见下方字段说明 */ } ]
}
```

`radios[]` 字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | int | 电台 id，用于取详情 / 播放 |
| `name` | string | 电台名称 |
| `imgUrl` | string | 台标图片；可能是 `http://`，也带 OSS 处理参数 |
| `playUrl` | string | **主播放源**，多为 m3u8，直播流 |
| `playUrl2` | string | **备用播放源**，radio.cn 的 m3u8（URL 中含时效 token） |
| `programme` | string | 节目单，**字符串形式的 JSON 数组**，需二次 `JSON.parse` |
| `desc` | string | 简介，常为 `"暂无节目信息"` |
| `province_id` | string | 所属省份 id |
| `category_id` | int | 所属类型 id |
| `playcount` / `new_playcount` | int | 累计 / 近期播放量 |
| `custom` | int | 2 = 系统电台，0 = 其他 |
| `platform` | string | 来源平台，如 `"xm"`（喜马拉雅） |
| `platform_id` | string | 来源平台的频道 id |
| `replay_platform` | string | 回听平台，如 `"qt"`（蜻蜓） |
| `sort` | int | 排序权重 |
| `bq` | int | 标签位 |
| `p_id` | int | 上游频道 id |
| `channelTitle` | string | 上游渠道标识 |
| `listener_count` | int | 当前收听人数 |
| `update_date` | long | 更新时间（毫秒时间戳） |

单条示例：

```json
{
  "id": 3259,
  "name": "北京新闻广播FM945",
  "imgUrl": "http://imagev2.xmcdn.com/storages/.../CWkRIJEEjOalAAD6CwCz_kFo.jpg",
  "playUrl": "https://brtv-radiolive.rbc.cn/alive/fm945.m3u8",
  "playUrl2": "http://ytcast.radio.cn/59/radios/20353/index_20353.m3u8?type=1&key=c24ee...&time=6addfc66",
  "province_id": "110000",
  "category_id": 5,
  "playcount": 1014610,
  "new_playcount": 93977,
  "listener_count": 0,
  "custom": 2,
  "platform": "xm",
  "platform_id": "353",
  "replay_platform": "qt",
  "p_id": 339,
  "channelTitle": "yt",
  "sort": 6,
  "bq": 0,
  "update_date": 1792932966000,
  "desc": "暂无节目信息",
  "programme": "[{\"duration\":600,\"start_time\":\"21:00:00\",\"end_time\":\"21:10:00\",\"title\":\"整点快报\",\"day\":1,\"playUrl\":\"https://lcache.qtfm.cn/cache/20261025/339/339_20261025_210000_211000_24_0.aac\"}]"
}
```

`programme[]` 可解析出的字段：

| 字段 | 说明 |
|---|---|
| `title` | 节目名 |
| `start_time` / `end_time` | `HH:mm:ss`，**北京时间** |
| `duration` | 时长（秒） |
| `day` | 0/1，0 = 昨日节目，1 = 今日 |
| `playUrl` | 该节目的回听地址（仅当日有效） |
| `res_id` / `channel_id` / `program_id` / `id` | 上游标识 |

---

## 3. 播放源（刷新）

`POST /radio/getRadio`

参数：

| 字段 | 类型 | 说明 |
|---|---|---|
| `rid` | string | 电台 id（列表里的 `id`） |

响应 `data`：`{ "radio": { ... } }`，结构同列表项。

**为什么要单独调**：`playUrl2`（以及部分 `playUrl`）里的 token / 时效参数会过期，App 每次开始播放前都会用 `rid` 重新取一次最新地址。建议同样处理，失败时回退到列表里缓存的地址。

---

## 4. 搜索

`POST /radio/getSearchRadio`

参数：

| 字段 | 类型 | 说明 |
|---|---|---|
| `content` | string | 关键词，如 `"交通"` |

响应 `data`：`{ "radios": [...], "audio": "..." }`

- `radios`：结构同第 2 节
- `audio`：音频搜索结果（字符串），App 未使用

---

## 5. 参考实现（Python）

```python
import base64, json, uuid, urllib.parse, urllib.request
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

BASE = "http://49.232.234.212"
KEY = b"ILOVERADIO666666"

def aes_enc(text):                      # -> base64
    return base64.b64encode(AES.new(KEY, AES.MODE_ECB).encrypt(pad(text.encode(), 16))).decode()

def aes_dec(b64):                       # -> str
    return unpad(AES.new(KEY, AES.MODE_ECB).decrypt(base64.b64decode(b64)), 16).decode()

def post(path, extra=None):
    params = {
        "imei": str(uuid.uuid4()), "uid": str(uuid.uuid4()),
        "device": "2", "qd": "2002", "version": "1.2.5",
        "model": "Andriod", "channelid": "Andriod",
    }
    params.update(extra or {})
    body = urllib.parse.urlencode({"sign": aes_enc(json.dumps(params, separators=(",", ":")))}).encode()
    req = urllib.request.Request(BASE + path, data=body, method="POST")
    req.add_header("Accept", "application/json;charset=UTF-8")
    req.add_header("Content-Type", "application/x-www-form-urlencoded; charset=utf-8")
    j = json.loads(urllib.request.urlopen(req, timeout=15).read())
    if isinstance(j.get("data"), str) and j["data"]:
        j["data"] = json.loads(aes_dec(j["data"]))
    return j

print(post("/radio/getAllCategory"))
```

完整可运行版本见仓库根目录 `api/client.py`。

---

## 6. 其它（未在 App 中使用，仅记录）

| 路径 | 说明 |
|---|---|
| `/radio/addCustom` / `/radio/deleteCustomRadio` | 自定义电台增删 |
| `/radio/getRadioBackList` | 回听列表 |
| `/audio/getNewTracks` / `/audio/searchAudio` | 音频节目 / 音频搜索 |
| `/config/getAppConfig` | 启动配置 |
| `/config/getAppUpdateContent` | 版本更新内容 |
| `/config/getFeedbackRespMeg` | 反馈回复 |
| `/config/uploadImage` | 图片上传 |
| `/user/login`、`/user/getCode`、`/user/addUser`、`/user/userInfo` | 登录注册 |
| `/user/getUserRadios`、`/user/radiosIds`、`/user/synRadioIds`、`/user/userRadioFix` | 收藏同步 |
| `/user/bindAccount`、`/user/unBindAccount` | 三方账号绑定 |
| `/cache/getRadioList` | 旧版缓存列表（服务端已坏，必抛 `NumberFormatException`） |
