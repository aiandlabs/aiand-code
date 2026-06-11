import { Effect } from "effect"
import { PluginV2 } from "../../plugin"
import { ProviderV2 } from "../../provider"

// aiand fork: route the managed provider's model calls through our own gateway
// (worker-inference) instead of OpenCode Zen. Overridable via OPENCODE_GATEWAY_URL
// for staging/local. Upstream resolves this from models.dev (https://opencode.ai/zen/v1).
const aiandGatewayUrl = process.env["OPENCODE_GATEWAY_URL"] ?? "https://api.aiand.com/v1"

export const OpencodePlugin = PluginV2.define({
  id: PluginV2.ID.make("opencode"),
  effect: Effect.gen(function* () {
    let hasKey = false
    return {
      "catalog.transform": Effect.fn(function* (evt) {
        const item = evt.provider.get(ProviderV2.ID.opencode)
        if (!item) return
        hasKey = Boolean(
          process.env.OPENCODE_API_KEY ||
            item.provider.env.some((env) => process.env[env]) ||
            item.provider.request.body.apiKey ||
            (item.provider.enabled && item.provider.enabled.via === "credential"),
        )
        evt.provider.update(item.provider.id, (provider) => {
          // Override the OpenCode Zen baseURL with the aiand gateway. The catalog
          // normalizer promotes request.body.baseURL into the provider's api.url.
          provider.request.body.baseURL = aiandGatewayUrl
          if (!hasKey) provider.request.body.apiKey = "public"
        })
        if (hasKey) return
        for (const model of item.models.values()) {
          if (!model.cost.some((cost) => cost.input > 0)) continue
          evt.model.update(item.provider.id, model.id, (draft) => {
            draft.enabled = false
          })
        }
      }),
    }
  }),
})
