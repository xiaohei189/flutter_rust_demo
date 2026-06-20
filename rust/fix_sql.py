import re

with open('src/infra/database/conversation_dao.rs', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 第 16 行（索引 15）是原 upsert SQL
line16 = lines[15]
# 第 54 行（索引 53）是新方法的 SQL
line54 = lines[53]

# 提取 VALUES ... ON 之间的部分
m16 = re.search(r'(VALUES\s*\([^)]*\)\s*ON)', line16)
m54 = re.search(r'(VALUES\s*\([^)]*\)\s*ON)', line54)

if m16 and m54:
    values_and_on_16 = m16.group(1)
    values_and_on_54 = m54.group(1)
    print(f'原 VALUES+ON: {values_and_on_16}')
    print(f'原 VALUES+ON 问号数: {values_and_on_16.count("?")}')
    print(f'新 VALUES+ON: {values_and_on_54}')
    print(f'新 VALUES+ON 问号数: {values_and_on_54.count("?")}')
    
    # 用原 VALUES 部分替换
    new_line54 = line54.replace(values_and_on_54, values_and_on_16)
    lines[53] = new_line54
    
    with open('src/infra/database/conversation_dao.rs', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print('修复完成')
else:
    print('没有找到匹配')
    print(f'line16: {line16[:100]}')
    print(f'line54: {line54[:100]}')
