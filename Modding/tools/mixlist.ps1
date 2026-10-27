param([string[]]$Mix, [string]$NamesFile)
# Lists entries of unencrypted TS MIX files; resolves names via XCC "local mix database.dat" or a names list.
Add-Type -TypeDefinition @"
public static class Crc32W {
  static uint[] t;
  static Crc32W(){ t=new uint[256]; for(uint i=0;i<256;i++){ uint c=i; for(int k=0;k<8;k++) c=((c&1)!=0)?(0xEDB88320u^(c>>1)):(c>>1); t[i]=c; } }
  public static uint Id(string n){
    n=n.ToUpperInvariant(); int l=n.Length; int a=l>>2<<2;
    if((l&3)!=0){ n+=(char)(l-a); char p=n[a]; for(int i=0;i<3-(l&3);i++) n+=p; }
    uint c=0xFFFFFFFFu; foreach(char ch in n) c=t[(c^(byte)ch)&0xFF]^(c>>8); return c^0xFFFFFFFFu; }
}
"@
$known=@{}
if($NamesFile){ Get-Content $NamesFile | ForEach-Object { if($_){ $known[[Crc32W]::Id($_)]=$_ } } }
$lmdId=[Crc32W]::Id('local mix database.dat')
foreach($m in $Mix){
  $fs=[IO.File]::OpenRead((Resolve-Path $m)); $br=New-Object IO.BinaryReader($fs)
  $flags=$br.ReadUInt32(); if($flags -band 0x20000){ "$m : encrypted, skipped"; $fs.Close(); continue }
  $cnt=$br.ReadUInt16(); $null=$br.ReadUInt32(); $ents=@()
  for($i=0;$i -lt $cnt;$i++){ $ents+= [pscustomobject]@{Id=$br.ReadUInt32();Off=$br.ReadUInt32();Size=$br.ReadUInt32()} }
  $body=$fs.Position; $names=@{}
  $lmd=$ents | Where-Object Id -eq $lmdId
  if($lmd){ $fs.Position=$body+$lmd.Off; $buf=$br.ReadBytes($lmd.Size); $s=[Text.Encoding]::ASCII.GetString($buf,52,$buf.Length-52)
    $s.Split([char]0) | Where-Object { $_ } | ForEach-Object { $names[[Crc32W]::Id($_)]=$_ } }
  $fs.Close()
  "== $m ($cnt entries, LMD=$([bool]$lmd))"
  $ents | ForEach-Object { $n=$names[$_.Id]; if(-not $n){ $n=$known[$_.Id] }; if(-not $n){ $n=('?{0:X8}' -f $_.Id) }; "{0,-28} {1,10}" -f $n,$_.Size } | Sort-Object
}
