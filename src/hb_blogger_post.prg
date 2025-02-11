/* Keeping it tidy */
#pragma -w3
#pragma -es2

/* Optimizations */
#pragma -km+
#pragma -ko+

#require "hbssl"
#require "hbtip"

REQUEST HB_CODEPAGE_UTF8EX

#if ! defined( __HBSCRIPT__HBSHELL )
    REQUEST __HBEXTERN__HBSSL__
#endif

#include "tip.ch"
#include "inkey.ch"
#include "fileio.ch"
#include "hbclass.ch"

// Defina suas credenciais e chaves (substitua pelos seus valores)
static cNewsApiKey as character // API key para o serviço de notícias
static cBloggerID as character // ID do seu blog no Blogger
static cBloggerAccessToken as character // Blogger API Key

// Variáveis globais para OAuth2
static cClientID as character
static cClientSecret as character
static cRedirectURI as character
static cAuthURL as character
static cTokenURL as character
static cScope as character

static cEOL as character

MEMVAR server, get, post, cookie, session

//---------------------------------------------------------------------
// Função: Main()
// Executa o fluxo: busca notícias -> gera Markdown -> converte para HTML -> publica no Blogger
//---------------------------------------------------------------------
procedure Main()

    local cHtml as character
    local cTitle as character
    local cMarkdown as character
    local cNewsJSON as character

    local lSuccess as logical:=.F.

    cEOL:=hb_eol()
    hb_setCodePage("UTF8")
    hb_cdpSelect("UTF8EX")

    SET DATE ANSI
    SET CENTURY ON

    #ifdef __ALT_D__    // Compile with -b
        AltD(1)         // Enables the debugger. Press F5 to go.
        AltD()          // Invokes the debugger
    #endif

    begin sequence

        cNewsApiKey:=GetEnv("NEWS_API_KEY") // API key para o serviço de notícias
        // 1. Buscar notícias de tecnologia
        cNewsJSON:=GetNews()

        // 2. Processar JSON e gerar Markdown
        cMarkdown:=JSONToMarkdown(cNewsJSON)

        // 3. Converter Markdown para HTML (Blogger requer HTML)
        if (!Empty(cMarkdown))
            cHtml:=ConvertMarkdownToHtml(cMarkdown)
            // 4. Publicar o post no Blogger
            cTitle:="BlackTDN NEWS :: "+DToC(Date())+" :: "+Time()
            lSuccess:=PublishToBlogger(cTitle,cHtml)
        endif

        if (lSuccess)
          ? "Post publicado com sucesso!"
        else
          ? "Falha ao publicar o post."
        endif

    end sequence

    return

//---------------------------------------------------------------------
// Função: GetNews()
// Usa TIPClientHTTP para efetuar uma requisição GET à API de notícias.
//---------------------------------------------------------------------
static function GetNews()

    local cURL as character
    local cResponse as character

    local oURL as object
    local oHTTP as object

    cURL:="https://newsapi.org/v2/everything/"

    //FixMe!
    cURL:=strTran(cURL,"https","http")

    // Cria objeto TUrl (construtor definido na TIP – ver tipwget.prg)
    oURL:=TUrl():New(cURL)
    oHTTP:=TIPClientHTTP():New(oURL)
    oHTTP:hFields["Content-Type"]:="application/JSON"
    oHTTP:hFields["X-Api-Key"]:=cNewsApiKey

    /* build the search query and add it to the TUrl object */
    oHTTP:oURL:addGetForm(;
        {;
            "q" => "tecnologia";
           ,"sortBy" => "popularity";
           ,"language" => "pt";
           ,"from" => hb_DToC(Date(),"yyyy-mm-dd");
           ,"to" => hb_DToC(Date(),"yyyy-mm-dd");
           ,"apiKey" => cNewsApiKey;
        };
    )

    /* Connect to the HTTP server */
    oHTTP:nConnTimeout:=2000 /* 20000 */

    ? "Connecting to",oURL:cProto+"://"+oURL:cServer+oURL:cPath+"?"+oURL:cQuery

    if (oHTTP:Open())
        ? "Connection status:",iif(Empty(oHTTP:cReply),"<connected>",oHTTP:cReply)
        /* download the response */
        cResponse:=oHTTP:ReadAll()
        if (Empty(cResponse))
            ? oHTTP:LastErrorMessage(oHTTP:SocketCon)
        endif
        oHTTP:Close()
    else
         ? oHTTP:LastErrorMessage(oHTTP:SocketCon)
    endif

    hb_default(@cResponse,"")

    return(cResponse) as character

//---------------------------------------------------------------------
// Função: JSONToMarkdown(cJSON)
// Gera um texto em Markdown formatado com título, descrição e link para cada notícia.
//---------------------------------------------------------------------
static function JSONToMarkdown(cJSON as character)

    local aArticles as array

    local cMarkdown as character := ""

    local hJSON as hash

    local hArticle as hash

    local i as numeric

    hb_MemoWrit("C:\tmp\news.json",cJSON)

    hb_JSONDecode(cJSON,@hJSON)

    begin sequence

        if (!hb_HHasKey(hJSON,"status"))
            break
        endif

        if (hJSON["status"]!="ok")
            break
        endif

        if (hb_HHasKey(hJSON,"totalResults"))
            if (hJSON["totalResults"]==0)
                break
            endif
        endif

        if (!hb_HHasKey(hJSON,"articles"))
            break
        endif

        aArticles:=hJSON["articles"]

        for i:=1 to Len(aArticles)

            hArticle:=aArticles[i]

            // Título da notícia
            cMarkdown+="# "+if(!Empty(hArticle["title"]),hArticle["title"],hArticle["description"])+cEOL

            // Fonte e autor
            cMarkdown+="**Fonte:** "+hArticle["source"]["name"]+cEOL
            if (!Empty(hArticle["author"]))
                cMarkdown+="**Autor:** "+hArticle["author"]+cEOL
            endif

            // Data de publicação
            cMarkdown+="**Publicado em:** "+hArticle["publishedAt"]+cEOL+cEOL

            // Imagem (se disponível)
            if (!Empty(hArticle["urlToImage"]))
                cMarkdown+="![Imagem]("+hArticle["urlToImage"]+")"+cEOL+cEOL
            endif

            // Descrição (citação)
            if (!Empty(hArticle["description"]))
                cMarkdown+="> "+hArticle["description"]+cEOL+cEOL
            endif

            // Link para a notícia completa
            cMarkdown+="[Leia mais]("+hArticle["url"]+")"+cEOL+cEOL

            // Separador entre notícias
            cMarkdown+="---"+cEOL+cEOL

        next i

    end sequence

    return(cMarkdown) as character

//---------------------------------------------------------------------
// Função: ConvertMarkdownToHtml( cMarkdown )
//---------------------------------------------------------------------
static function ConvertMarkdownToHtml(cMarkdown as character)
   local cNewMarkDown as character
#pragma __cstream|cNewMarkDown:=%s
<div class="separator" style="clear: both;"><a href="https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgKfeXkOvdidB4y-2xSljMmUFRf1l432sFeW5_1prYw2SnGtOvI2HtkDBm-aRNHt5wUGkjcEGtVrWYKGegXsmoX84C1C6V-aWJoj0jY49MwAiR6Jxecyzp1Sfgj9-V64KUCAQ2bTt3kFHEP5px2eoWeXwV5-nZ6YvXd8nEfMmaK-c4Mo0JAgqCDg33Kxo8/s1792/blacktdn_new_banner.webp" style="display: block; padding: 1em 0; text-align: center; "><img alt="" border="0" width="400" data-original-height="1024" data-original-width="1792" src="https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgKfeXkOvdidB4y-2xSljMmUFRf1l432sFeW5_1prYw2SnGtOvI2HtkDBm-aRNHt5wUGkjcEGtVrWYKGegXsmoX84C1C6V-aWJoj0jY49MwAiR6Jxecyzp1Sfgj9-V64KUCAQ2bTt3kFHEP5px2eoWeXwV5-nZ6YvXd8nEfMmaK-c4Mo0JAgqCDg33Kxo8/s400/blacktdn_new_banner.webp"/></a></div>
#pragma __endtext
   cNewMarkDown+=cEOL
   cNewMarkDown+='<pre class="markdown">_Créditos das imagens: ChatGPT'+cEOL+cMarkdown+cEOL+'</pre>'
   return(cNewMarkDown) as character

//---------------------------------------------------------------------
// Função: PublishToBlogger( cTitle, cContent )
// Publica o post no Blogger via API REST usando TIPClientHTTP.
//---------------------------------------------------------------------
static function PublishToBlogger(cTitle as character,cContent as character)

    local cURL as character
    local cAccessToken  as character
    local cJSONData as character
    local cResponse as character

    local hJSONData as hash

    local oURL as object
    local oHTTP as object

    cBloggerID:=GetEnv("BLOGGER_ID") // ID do seu blog no Blogger
    cBloggerAccessToken:=GetEnv("BLOGGER_API_KEY") // Blogger API Key

    // Variáveis globais para OAuth2
    cClientID:=GetEnv("GOOGLE_CLIENT_ID")
    cClientSecret:=GetEnv("GOOGLE_CLIENT_SECRET")
    cRedirectURI:="http://localhost:8002/oauth2callback"
    cAuthURL:="https://accounts.google.com/o/oauth2/v2/auth"
    cTokenURL:="https://accounts.google.com/o/oauth2/token"
    cScope:="https://www.googleapis.com/auth/blogger"

    cAccessToken:=GetOAuth2Token() // Obter token via OAuth2

    if (!Empty(cAccessToken))

        // Constrói a URL do endpoint de inserção de posts do Blogger
        cURL:="https://www.googleapis.com/blogger/v3/blogs/"+cBloggerID+"/posts/"

        // Prepara o corpo JSON da requisição conforme a documentação do Blogger API v3
        hJSONData:={;
                        "kind" => "blogger#post";
                       ,"blog" => {;
                            "id" => cBloggerID;
                        };
                       ,"title" => cTitle;
                       ,"content" => cContent;
        }

        // Cria o objeto TIPClientHTTP para a URL do Blogger
        oURL:=TUrl():New(cURL)
        oHTTP:=TIPClientHTTP():New(oURL)

        // Define os cabeçalhos adicionais (em hFields – conforme a implementação TIP)
        oHTTP:hFields["Authorization"]:="Bearer "+cAccessToken
        oHTTP:hFields["Content-Type"]:="application/JSON"

        // Efetua a requisição POST com o corpo JSON
        cJSONData:=hb_JSONEncode(hJSONData)

        if (oHTTP:Open())
            if (oHTTP:Post(cJSONData))
                ? cResponse:=oHTTP:cReply
                ? hb_ValToExp(oHTTP:hHeaders)
            else
                ? "Error:", "oHTTP:Post()", oHTTP:LastErrorMessage()
            endif
            oHTTP:Close()
        else
            ? "Error:", "oHTTP:Open()", oHTTP:LastErrorMessage()
        endif

    endif

    return(!Empty(cResponse)) as logical

//---------------------------------------------------------------------
// Função: GetOAuth2Token()
// Obtém um token de acesso via OAuth2 (Authorization Code Flow)
//---------------------------------------------------------------------
static function GetOAuth2Token()

    local cAccessToken as character

    local lHTTPServer as logical

    local oLogError,oLogAccess as object
    local oHTTPServer as object

    ? "http://localhost:8002/"
    hb_idleSleep(.1)

    oLogError:=UHttpdLog():New("hb_blogger_post_error.log")
    oLogAccess:=UHttpdLog():New("hb_blogger_post_access.log")

    if (hb_FileExists(".uhttpd.stop"))
        fErase(".uhttpd.stop")
    endif

    // Configurar rotas
    oHTTPServer:=UHttpdNew()
    lHTTPServer:=oHTTPServer:Run(;
        {;
             "FirewallFilter"   => "";
            ,"LogAccess"        => {| m | oLogAccess:Add( m+cEOL ) };
            ,"LogError"         => {| m | oLogError:Add( m+cEOL ) };
            ,"Trace"            => {| ... | QOut( ... ) };
            ,"Port"             => 8002;
            ,"Idle"             => {|o|iif(hb_FileExists(".uhttpd.stop"),(fErase(".uhttpd.stop"),o:Stop()),NIL)};
            ,"SSL"              => .F.;
            ,"Mount"            => {;
                 "/info"           => {||UProcInfo()};
                ,"/auth"           => @AuthHandler();// Inicia o fluxo OAuth2
                ,"/oauth2callback" => @CallbackHandler();// Recebe o código de autorização
                ,"/"               => {||URedirect("/auth")};
            };
        };
    )

    oLogError:Close()
    oLogAccess:Close()

    if (lHTTPServer)

        if (file("hb_blogger_post.token"))
            cAccessToken:=hb_MemoRead("hb_blogger_post.token")
            fErase("hb_blogger_post.token")
        else
            hb_default(@cAccessToken,"")
        endif

    else

        hb_default(@cAccessToken,"")

    endif

    return(cAccessToken)

static function AuthHandler()

    local cParams as character:=""
    local cKey,cValue as character
    local hkey as hash
    local hkeys as hash := {;
         "redirect_uri"   => cRedirectURI;
        ,"prompt"        => "consent";
        ,"response_type" => "code";
        ,"client_id"     => cClientID;
        ,"scope"         => cScope;
    }

    for each hkey in hkeys
        cKey:=hKey:__enumKey()
        cValue:=hKey:__enumValue()
        cParams+=tip_URLEncode(AllTrim(hb_CStr(cKey)))+"="+tip_URLEncode(AllTrim(cValue))
        if (!hkey:__enumIsLast())
            cParams+="&"
         endif
    next each

    if (Right(cParams,1)=="&")
        cParams:=SubStr(cParams,1,Len(cParams)-1)
    endif

    USessionStart()
    URedirect(cAuthURL+"?"+cParams) // Redireciona o navegador

return(.T.)

static function CallbackHandler()

    local cAuthCode,cAccessToken as character

    if (hb_HHasKey(get,"code"))
        cAuthCode:=get["code"]
        cAccessToken:=ExchangeCodeForToken(cAuthCode)
        hb_MemoWrit("hb_blogger_post.token",cAccessToken)
   endif

   hb_MemoWrit(".uhttpd.stop","")

return({"AccessToken"=>cAccessToken})

static function ExchangeCodeForToken(cAuthCode as character)

    local cTokenResponse, cAccessToken

    local hkeys,hJSONResponse as hash

    local oURL as object
    local oHTTP as object

    // 2. Trocar código por token de acesso
    hkeys:={;
        "code"          => cAuthCode,;
        "redirect_uri"  => cRedirectURI,;
        "client_id"     => cClientID,;
        "client_secret" => cClientSecret,;
        "grant_type"    => "authorization_code";
    }

    // Cria o objeto TIPClientHTTP para a URL do Blogger
    oURL:=TUrl():New(cTokenURL)
    oHTTP:=TIPClientHTTP():New(oURL)
    oHTTP:hFields["Content-Type"]:="application/x-www-form-urlencoded"

    if (oHTTP:Open())
        if (oHTTP:Post(hkeys))
            cTokenResponse:=oHTTP:ReadAll()
            QOut( "cTokenResponse", cTokenResponse )
            hb_JSONDecode(cTokenResponse,@hJSONResponse)
            if (hb_HHasKey(hJSONResponse,"access_token"))
                cAccessToken:=hJSONResponse["access_token"]
                QOut( "cAccessToken", cAccessToken )
                hb_MemoWrit("hb_blogger_post.token",cAccessToken)
                hb_MemoWrit(".uhttpd.stop","")
            endif
            ? hb_ValToExp(oHTTP:hHeaders)
        else
            QOut( "Error:", "oHTTP:Post()", oHTTP:LastErrorMessage() )
            ? "Error:", "oHTTP:Post()", oHTTP:LastErrorMessage()
        endif
        oHTTP:Close()
    else
        ? "Error:", "oHTTP:Open()", oHTTP:LastErrorMessage()
        QOut( "Error:", "oHTTP:Open()", oHTTP:LastErrorMessage() )
    endif

return(cAccessToken)

//---------------------------------------------------------------------
// Fim do programa
//---------------------------------------------------------------------
