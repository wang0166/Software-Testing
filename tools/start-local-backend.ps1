param(
    [string]$MavenCommand = 'mvn',
    [string]$MavenRepository = '',
    [string]$DataDirectory = '个人资料/开发/本地后端',
    [ValidateRange(1024,65535)][int]$Port = 8080,
    [switch]$Stop
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$dataPath = if ([IO.Path]::IsPathRooted($DataDirectory)) {
    [IO.Path]::GetFullPath($DataDirectory)
} else { [IO.Path]::GetFullPath((Join-Path $projectRoot $DataDirectory)) }
if ($Stop) {
    if (!(Test-Path -LiteralPath (Join-Path $dataPath 'PG_VERSION'))) { throw '指定目录没有本地 PostgreSQL 数据，不写入停止标记。' }
    [IO.File]::WriteAllText((Join-Path $dataPath '.stop-request'), 'stop')
    Write-Host '已请求本地后端正常停止，数据库文件保留。'
    return
}
$previousPassword = $env:ADMIN_INIT_PASSWORD
$previousUsername = $env:ADMIN_INIT_USERNAME
try {
    if (!$env:ADMIN_INIT_PASSWORD) {
        $securePassword = Read-Host '输入本地初始管理员密码（不回显；已有管理员时不会覆盖密码）' -AsSecureString
        $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        try { $env:ADMIN_INIT_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
    }
    if ([string]::IsNullOrWhiteSpace($env:ADMIN_INIT_PASSWORD) -or $env:ADMIN_INIT_PASSWORD.Length -lt 6 -or
            [Text.Encoding]::UTF8.GetByteCount($env:ADMIN_INIT_PASSWORD) -gt 72) {
        throw '本地初始密码至少 6 位、不能全为空格，UTF-8 编码最多 72 字节。'
    }
    if (!$env:ADMIN_INIT_USERNAME) { $env:ADMIN_INIT_USERNAME = 'admin' }
    New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
    # initdb 要求全新数据目录为空，运行类路径单独保存，不能放进数据库目录。
    $runtimeDirectory = Join-Path $projectRoot '个人资料/开发/验证'
    New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
    $classpathFile = Join-Path $runtimeDirectory 'local-backend-classpath.txt'
    Push-Location $projectRoot
    try {
        $mavenArguments = @('-q', '-DskipTests', 'test-compile', 'dependency:build-classpath', '-Dmdep.includeScope=test', "-Dmdep.outputFile=$classpathFile")
        if ($MavenRepository) { $mavenArguments += "-Dmaven.repo.local=$MavenRepository" }
        & $MavenCommand @mavenArguments
        if ($LASTEXITCODE -ne 0) { throw '本地后端编译或依赖解析失败。' }
        $runtimeClasspath = (Join-Path $projectRoot 'target/test-classes') + [IO.Path]::PathSeparator +
            (Join-Path $projectRoot 'target/classes') + [IO.Path]::PathSeparator + [IO.File]::ReadAllText($classpathFile).Trim()
        Write-Host "本地 API：http://127.0.0.1:$Port/api；管理员账号：$env:ADMIN_INIT_USERNAME"
        Write-Host '数据库只监听本机，数据保留；重启后需重新登录。使用同一脚本加 -Stop 正常停止。'
        $javaCommand = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin/java.exe' } else { 'java' }
        & $javaCommand -cp $runtimeClasspath com.pandora.log.LocalBackendLauncher $dataPath $Port
        if ($LASTEXITCODE -ne 0) { throw '本地后端启动失败，请检查端口与错误信息。' }
    } finally { Pop-Location }
} finally {
    $env:ADMIN_INIT_PASSWORD = $previousPassword
    $env:ADMIN_INIT_USERNAME = $previousUsername
}
