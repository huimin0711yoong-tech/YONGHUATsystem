# YONGHUAT SYSTEM — 老板使用说明

网址：**https://yonghuatsystem.vercel.app**（电脑和手机都可以用）

---

## 1. 这个系统做什么

每天早上打开，就知道两件事：

1. **哪些订单急着要送** —— 没送货越久，颜色越红。
2. **哪些货要马上订** —— 在捡货（picking）时因为缺货被删掉最多次的货品。

资料从 **eFichain** 的 Excel 来（Daily Order Details Fulfillment report），由经理每天上传。

| 功能 | 在哪里 | 做什么 |
|---|---|---|
| 🔔 提醒框 | 首页 | 早上 8:00 后显示今天的红色 / 橙色订单、缺货货品、等批准的表格 |
| 📊 Dashboard | 菜单 | 5 个重点数字、未送货订单表、Top 10 缺货、过滤器、AI 早报 |
| 📤 上传 Excel | 菜单 | 上传 eFichain Excel（同一份上传两次不会重复） |
| 🚚📦 员工表格 | 菜单 | 员工填"安排送货"或"需要订货" |
| ✅ 表格处理 | 菜单 | 经理批准 / 拒绝 / 标完成 |
| 👥 用户管理 | 菜单（只有老板） | 改角色、停用账号 |
| ⚙️ 设定 | 菜单（只有老板） | 改规则数字（红色几天、Top 几名、提醒时间） |

**颜色规则（可以在设定页改）：**
- 🔴 红色 = 从 S/O 日期算起，**3 天或以上**还没送
- 🟠 橙色 = **1–2 天**还没送
- 星期六、星期日、公共假期都算天数
- **DRAFT（草稿）** 和 **VOID** 的单不算；捡货时被删（DELETED）的货也不算未送货

---

## 2. 谁可以做什么

| | 老板 (Boss) | 经理 (Manager) | 员工 (Staff) |
|---|---|---|---|
| 看提醒框 | ✅ 全部 | ✅ 全部 | ✅ 红/橙数量 + 缺货名单（**看不到金额**） |
| 看 Dashboard、订单资料 | ✅ | ✅ | ❌ |
| 上传 eFichain Excel | ✅ | ✅ | ❌ |
| 填送货 / 订货表格 | ✅ | ✅ | ✅ 只看到**自己**填的 |
| 批准 / 拒绝 / 完成表格 | ✅ | ✅ | ❌ |
| WhatsApp 每日总结按钮 | ✅ | ✅ | ❌ |
| AI 早报 | ✅ | ✅ | ❌ |
| **删除**任何东西 | ✅ | ❌ | ❌ |
| 改别人的角色、停用账号 | ✅ | ❌ | ❌ |
| 改设定（规则数字） | ✅ | ❌（只能看） | ❌（只能看） |

- 销售经理、物流经理 = **Manager**
- 系统会记下每次新增、改状态、改角色、改设定、上传：谁、几时、做了什么。
- 就算有人想绕过网页，资料库本身也会挡住没权限的动作。

---

## 3. 怎样加一个新同事

1. 把网址 **https://yonghuatsystem.vercel.app** 发给他。
2. 他点 **New account**，填名字、email、密码（至少 6 个字），按 **Create account**。
3. 他去 email 点确认链接，再回网站 **Log in**。这时他是 **Staff**。
4. 老板登入 → 菜单点 **Users** → 找到他 → 角色选 **Manager** 或保持 **Staff**。
5. 请他刷新网页，菜单就会改变。

**同事离职：** Users → 找到他 → 按 **Turn off**。他马上什么都看不到，也不能自己打开。旧的表格和记录会保留。

---

## 4. 每天的流程

### 早上（经理）
1. 在 eFichain 导出 **Daily Order Details Fulfillment** Excel。
2. 系统菜单 → **Upload eFichain Excel** → 选文件 → 检查总结的数字（几行、几张单、日期）→ 按 **Upload to system**。
3. 打开首页 **🔔 Alerts**：
   - 如果出现 ⚠️ "Data is old"，表示今天还没上传，回到第 1 步。
4. 按绿色 **WhatsApp** 按钮 → 选公司群组 → **自己按发送**。
5. 打开 **Dashboard**：
   - 🔴 红色订单 → **今天安排送货**
   - 📦 Top 10 缺货 → **今天订货**
6. 打开 **Forms to handle** → 批准或拒绝新表格，先处理标红色 **LATE** 的。
7. （可选）Dashboard 最下面做 **AI 早报**：Make prompt → 复制到 Claude → 贴回答案 → **对照数字检查** → 打勾 → Save。

### 白天（员工）
- 需要安排送货：**Arrange delivery** → 填 S/O 号码和日期。
- 发现缺货：**Need to reorder** → 填货品和数量。
- 在 **My forms** 和提醒框看经理有没有批准。

### 下班前（经理）
- 送完或订好的，在 **Forms to handle** 按 **Mark as done**。

---

## 5. 每个星期的流程（老板，大约 10 分钟）

1. **Users**：有没有不认识的账号？离职的人有没有 Turn off？
2. **Dashboard**：红色订单有没有比上个星期少？哪个业务员 / 哪个 Division 最多红色（用过滤器看）？
3. **Top 10 缺货**：同一样货是不是每个星期都在名单上？要不要多订一点库存？
4. **Forms to handle** → 按 **Approved**：有没有批准了很久还没完成的？
5. **Settings** → **Recent changes**：有没有人改过规则？
6. 每个月一次：Supabase → **Advisors → Security Advisor**，看有没有新的红色或黄色提醒（现在应该只剩 3 个故意保留的 "Signed-In Users Can Execute"）。

---

## 6. 放真的客户资料之前，要检查什么

> ⚠️ **注意：** 测试时我们已经上传过一份 **1–16 Nov 2026 的真实 eFichain Excel**，里面有真实客户名和金额。下面的检查做好之前，请老板决定这份资料要保留还是清掉。

### 账号和密码
- [ ] 只有需要的人有账号；测试账号已经 **Turn off**。
- [ ] 只有 1–2 个 **Boss**。
- [ ] 每个人用自己的账号，**不共用**密码。
- [ ] Supabase → Authentication → 打开 **Prevent use of leaked passwords**（如果你的配套有这个功能）。
- [ ] Supabase → Authentication → 确认 **Confirm email** 是打开的（新账号要点 email 确认）。

### 权限测试（用测试账号各试一次）
- [ ] **Staff** 登入：看不到 Dashboard、看不到金额、只看到自己的表格。
- [ ] **Manager** 登入：看不到 Users 和 Settings 的修改，不能删除。
- [ ] 被 **Turn off** 的账号：登入后什么都看不到。

### 资料放在哪里
- [ ] **Supabase 资料库在日本（Tokyo）**。确认公司可以接受客户资料存放在马来西亚以外（PDPA 个人资料保护法）。
- [ ] Supabase 免费配套：**一个星期没人用会暂停**，也**没有每日备份**。正式使用前，考虑升级付费配套，或者定期在 Supabase 导出备份。
- [ ] **GitHub** 的 YONGHUATsystem **现在是 Public（任何人都看得到代码和这份说明）**。请改成 **Private**：GitHub → YONGHUATsystem → Settings → General → 最下面 Danger Zone → Change visibility → Private。代码里没有密码，Excel 文件也不会上传，改了之后 Vercel 网站照常运作。
- [ ] 电脑里的 eFichain Excel 文件：放在只有经理能打开的地方，不要用 WhatsApp 乱传。

### AI 和 WhatsApp
- [ ] AI 早报的问题里有**客户名和金额**，只贴到**公司的 Claude 账号**，不要用私人的免费账号。
- [ ] AI 的答案一定要**对照 Dashboard 的数字**检查后才打勾保存。
- [ ] WhatsApp 总结只发到**公司内部群组**，不要发给客户。系统**从来不会自动发**任何东西给客户。

### 最后
- [ ] 把这份说明发给所有经理。
- [ ] 第一个星期每天对照 eFichain，确认红色 / 橙色的数字合理。

---

*有问题或想改功能，告诉 Claude，一次改一样。*
