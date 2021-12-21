require "uri"
require "json"

require "discordcr"

require "./discord_plugin"

module Saucenao
  enum IndexSite
    H_mags                # 0
    Disabled_h_anime      # 1
    Hcg                   # 2
    Disabled_ddb_objects  # 3
    Disabled_ddb_samples  # 4
    Pixiv                 # 5
    Pixivhistorical       # 6
    Disabled_anime        # 7
    Seiga_illust          # 8
    Danbooru              # 9
    Drawr                 # 10
    Nijie                 # 11
    Yandere               # 12
    Disabled_animeop      # 13
    Disabled_IMDb         # 14
    Disabled_Shutterstock # 15
    FAKKU                 # 16
    Reserved              # 17
    Nhentai               # 18
    TwoD_market           # 19
    Medibang              # 20
    Anime                 # 21
    H_Anime               # 22
    Movies                # 23
    Shows                 # 24
    Gelbooru              # 25
    Konachan              # 26
    Sankaku               # 27
    Anime_pictures        # 28
    E621                  # 29
    Idol_complex          # 30
    Bcy_illust            # 31
    Bcy_cosplay           # 32
    Portalgraphics        # 33
    DA                    # 34
    Pawoo                 # 35
    Madokami              # 36
    Mangadex              # 37
    Ehentai               # 38
    ArtStation            # 39
    FurAffinity           # 40
    Twitter               # 41
    Furry_Network         # 42
    Mangadex1 = 371       # 371

    def to_json(io)
      io << '"'
      to_s(io)
      io << '"'
    end
  end

  class Parser
    include JSON::Serializable
    # @[JSON::Field(key: "header")]
    # getter header : Header
    @[YAML::Field(key: "results")]
    getter results : Array(Result)
  end

  class Result
    include JSON::Serializable
    @[JSON::Field(key: "header")]
    getter header : ResultHeader
    @[YAML::Field(key: "data")]
    getter data : ResultData
  end

  class ResultHeader
    include JSON::Serializable
    @[JSON::Field(key: "similarity", converter: StringToFloat)]
    getter similiarty : Float32
    @[YAML::Field(key: "thumbnail")]
    getter thumbnail : String
    @[JSON::Field(key: "index_id", converter: Enum::ValueConverter(Saucenao::IndexSite))]
    getter index_id : IndexSite
    @[YAML::Field(key: "index_name")]
    getter index_name : String
    @[JSON::Field(key: "dupes")]
    getter dupes : Int32
    @[YAML::Field(key: "hidden")]
    getter hidden : Int32
  end

  class ResultData
    include JSON::Serializable
    @[JSON::Field(key: "ext_urls")]
    getter ext_urls : Array(String)?

    # optional stuff
    @[JSON::Field(key: "title")]
    getter title : String?
    @[YAML::Field(key: "created_at", converter: StringToDate)]
    getter created_at : Time?
    @[JSON::Field(key: "author_name")]
    getter author_name : String?
    @[JSON::Field(key: "author_url", converter: StringToURI)]
    getter author_url : URI?

    @[JSON::Field(key: "creator")]
    getter creator : Array(String)? | String?

    @[JSON::Field(key: "member_name")]
    getter member_name : String?
    @[JSON::Field(key: "member_id")]
    getter member_id : Int32?
    @[JSON::Field(key: "member_link_id")]
    getter member_link_id : Int32?

    # # Twitter
    @[JSON::Field(key: "tweet_id")]
    getter tweet_id : String?
    @[JSON::Field(key: "tweet_user_id")]
    getter tweet_user_id : String?
    @[JSON::Field(key: "tweet_user_handle")]
    getter tweet_user_handle : String?

    # # Pawoo
    @[JSON::Field(key: "pawoo_id")]
    getter pawoo_id : String?
    @[JSON::Field(key: "pawoo_user_username")]
    getter pawoo_user_username : String?
    @[JSON::Field(key: "pawoo_user_acct")]
    getter pawoo_user_acct : String?
    @[JSON::Field(key: "pawoo_user_displayname")]
    getter pawoo_user_displayname : String?

    # # Booru
    @[JSON::Field(key: "danbooru_id")]
    getter danbooru_id : Int32?
    @[JSON::Field(key: "material")]
    getter material : String?
    @[JSON::Field(key: "characters")]
    getter characters : String?
    @[JSON::Field(key: "source")]
    getter source : String?

    # # DeviantArt
    @[JSON::Field(key: "da_id")]
    getter da_id : String?

    # # Pixiv
    @[JSON::Field(key: "pixiv_id")]
    getter pixiv_id : Int32?

    # # Furafinity
    @[JSON::Field(key: "fa_id")]
    getter fa_id : Int32?

    # # Furrynetwork
    @[JSON::Field(key: "fn_id")]
    getter fn_id : Int32?
    @[JSON::Field(key: "fn_type")]
    getter fn_type : Int32?

    # # E-hentai
    @[JSON::Field(key: "eng_name")]
    getter eng_name : String?
    @[JSON::Field(key: "jap_name")]
    getter jap_name : String?

    # # bcy.net
    @[JSON::Field(key: "bcy_id")]
    getter bcy_id : Int32?
    @[JSON::Field(key: "bcy_type")]
    getter bcy_type : String?

    # # Seiga
    @[JSON::Field(key: "seiga_id")]
    getter seiga_id : Int32?

    # # Anime
    @[JSON::Field(key: "anidb_aid")]
    getter anidb_aid : Int32?
    @[JSON::Field(key: "mal_id")]
    getter mal_id : Int32?
    @[JSON::Field(key: "anilist_id")]
    getter anilist_id : Int32?
    @[JSON::Field(key: "part")]
    getter part : String?
    @[JSON::Field(key: "year")]
    getter year : String?
    @[JSON::Field(key: "est_time")]
    getter est_time : String?
  end
end

module Discord
  class SaucenaoPlugin < DiscordPlugin
    getter api_endpoint : URI = URI.parse "https://saucenao.com/search.php"

    def initialize(token : String)
      api_endpoint.query_params = URI::Params{
        "output_type" => 2.to_s,
        "api_key"     => token,
        "dedupe"      => 2.to_s,
      }
      super(commands: Set{"sauce"}, name: "SauceNAO", passive: true)
    end

    def execute(command, client, payload)
      content = payload.content
      arguments = content.split(' ')[1..]

      case command
      when "sauce"
        output = "Sources:\n"
        arguments.each do |argument|
          output += construct_body(argument, 4)
        end
        client.create_message(payload.channel_id, output)
      else
        # Ignore.
      end
    end

    def passive(client, payload)
      images = 0
      threshold = 65.5


      output = "Sources:\n"

      payload.embeds.each do |embed|
        url = embed.url
        unless url.nil?
          body = construct_body(url, threshold: threshold)
          unless body.strip.empty?
            saucenao_url = api_endpoint.dup
            q = saucenao_url.query_params
            q.delete("api_key")
            q["output_type"] = 0.to_s
            q.add("url", url)
            saucenao_url.query_params = q
  
            images += 1
            output += "(from: #{saucenao_url})\n" + body
          end
        end
      end

      payload.attachments.each do |attachment|
        body = construct_body(attachment.url, threshold: threshold)
        Log.info { attachment.url.to_s }
        unless body.strip.empty?
          saucenao_url = api_endpoint.dup
          q = saucenao_url.query_params
          q.delete("api_key")
          q["output_type"] = 0.to_s
          q.add("url", attachment.url)
          saucenao_url.query_params = q

          images += 1
          output += "(from: #{saucenao_url})\n" + body
        end
      end
      
      if images > 0
        client.create_message(payload.channel_id, output)
      end
    end

    def construct_body(image_link : URI | String, limit : Int32 = 0, threshold : Float64 = 0)
      output = ""
      api_url = get_url image_link
      sauce = get_sauce api_url
      if sauce
        sauce.results.sort_by! { |result| result.header.similiarty }
        sauce.results.reverse!
        sauce.results[..limit].each do |result|
          similarity = result.header.similiarty
          data = result.data
          if similarity < threshold
            Log.info { "Threshold not met!" }
            next
          end
          case similarity
          when 0..60
            output += "🔴"
          when 60..80
            output += "🟠"
          when 80..90
            output += "🟡"
          when 90..
            output += "🟢"
          end
          output += " Similiarity #{similarity}% "
          case result.header.index_id
          when Saucenao::IndexSite::Anime
            output += "\n🎞️ #{data.source} Episode #{data.part} - #{data.est_time}\n"
          end
          urls = result.data.ext_urls
          unless urls.nil?
            urls.each { |url| output += "Link: <#{url}>\n" }
          end
        end
      end
      output
    end

    def get_url(image_link : URI | String)
      api_url = api_endpoint
      q = api_url.query_params
      q.add("url", image_link)
      api_url.query_params = q
      api_url
    end

    def get_sauce(url : URI) : Saucenao::Parser | Nil
      Log.info { "getting sauce for: #{url}" }
      response = HTTP::Client.get url
      if response.status_code==200
        begin
          Saucenao::Parser.from_json response.body
        rescue exception: JSON::SerializableError
          Log.error(exception:exception) { "Could not decode json!" }
          Log.error { response.body }
        end
      else 
        Log.warn { "Saucenao responded with #{response.status_code}"}
        Log.debug { response.body }
      end
    end
  end
end
