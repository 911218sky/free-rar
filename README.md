# free-rar

Windows helper scripts for installing WinRAR and deploying a legitimate
`rarreg.key` license file.

## Commands

Install WinRAR:

```powershell
.\free-rar.ps1 install
```

Install your `rarreg.key`:

```powershell
.\free-rar.ps1 license -KeyPath "C:\path\to\rarreg.key" -Force
```

Install WinRAR and then install your key:

```powershell
.\free-rar.ps1 all -KeyPath "C:\path\to\rarreg.key" -Force
```

`-KeyPath` can be a local file path or a private HTTPS URL.

```powershell
.\free-rar.ps1 license -KeyPath "https://github.com/911218sky/free-rar/releases/download/v0.1.0/rarreg.key"
```

## Remote usage after publishing to GitHub

Install WinRAR and deploy your own legitimate key directly from GitHub Raw:

```powershell
$script = [scriptblock]::Create((irm "https://raw.githubusercontent.com/911218sky/free-rar/main/free-rar.ps1"))
& $script all -KeyPath "https://github.com/911218sky/free-rar/releases/download/v0.1.0/rarreg.key"
```

Install WinRAR from GitHub Raw:

```powershell
$script = [scriptblock]::Create((irm "https://raw.githubusercontent.com/911218sky/free-rar/main/free-rar.ps1"))
& $script install -Force
```

Deploy your own legitimate key from a local file:

```powershell
$script = [scriptblock]::Create((irm "https://raw.githubusercontent.com/911218sky/free-rar/main/free-rar.ps1"))
& $script license -KeyPath "C:\path\to\rarreg.key" -Force
```

Deploy your own legitimate key from a private HTTPS URL:

```powershell
$script = [scriptblock]::Create((irm "https://raw.githubusercontent.com/911218sky/free-rar/main/free-rar.ps1"))
& $script license -KeyPath "https://github.com/911218sky/free-rar/releases/download/v0.1.0/rarreg.key" -Force
```
