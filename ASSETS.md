# Asset inventory

The following information assets are required to run https://catirclogs.org:

- Source control repository `whitequark/catirclogs.org`
  - Provider: [GitHub](https://github.com)
  - Owner: Catherine
  - Operators: Catherine, Charlotte
  - Link: https://github.com/whitequark/catirclogs.org
- Matrix channel `#admin:catircservices.org` (shared with https://catircservices.org)
  - Provider: [Matrix.org](https://matrix.org)
  - Owners/operators: Catherine, Charlotte
  - Link: https://matrix.to/#/#admin:catircservices.org
- Domain name `catirclogs.org`
  - Provider: [Gandi](https://gandi.net)
  - Owner: Catherine
  - Operators: Catherine, Charlotte
  - Link: https://admin.gandi.net/domain/1c9d73d2-a93a-11ed-9269-00163e816020/catirclogs.org/overview
  - Additional services provided:
    - DNS zone:
      ```zone
      @ 10800 IN MX 10 spool.mail.gandi.net.
      @ 10800 IN MX 50 fb.mail.gandi.net.
      @ 10800 IN TXT "v=spf1 include:_mailcust.gandi.net ?all"
      @ 600 IN A 78.47.223.64
      @ 600 IN AAAA 2a01:4f8:c012:6185::1
      * 10800 IN CNAME @
      ```
    - Email `admin@catirclogs.org` redirecting to `whitequark@gmail.com`
- Cloud server `78.47.223.64`, `2a01:4f8:c012:6185::/64` (DNS `catirclogs.org`)
  - Provider: [Hetzner](https://www.hetzner.com/cloud)
  - Owner: Catherine
  - Operators: Catherine, Charlotte
  - Link: https://console.hetzner.cloud/projects/2556857/servers/37165241/overview
  - Location: fsn1-dc14
