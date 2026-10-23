# Approved Figma implementation — working handoff

Source: https://www.figma.com/design/cbGKRRQZtyceFEiaDXDIP6
Base commit: ceb052d3bc51968d2476bd8745b386969cc3a42e
Implementation branch: feat/approved-figma-responsive-ui

## Implemented in this branch

- Approved light/dark semantic palette, Manrope headings, Inter body, and bundled open-license fonts (no runtime font request required by AppTypography).
- Saved appearance preference; System/Light/Dark selection in Settings and quick theme switch in shared headers.
- Shared desktop 224px sidebar, tablet 80px rail, mobile bottom navigation; navigation included on flat detail routes with Back/Home shortcuts.
- Dashboard semantic action colors, compact metrics and responsive action grid. Metric labels now reflect the actual provider values: assets, equity, liabilities and today's profit. They do not pretend that total assets equal liquid cash or equity equals receivables.
- Shared form sections, status and metric styling inherited by existing screens.
- Receive/Pay: bounded form width, persistent review action, existing account/deal selection and posting RPCs retained.
- Posted-transaction confirmation with Figma pulse timing and reduced-motion support, real receipt details, statement and sharing links.
- Attachment-upload failures after a successful post are reported without suggesting the payment be posted again.

## Verification and remaining work

- Local Flutter build/test invocation was blocked by automatic security review because the Flutter tool contacted an instance-metadata endpoint. It has not been retried through a workaround. Do not claim those checks passed.
- Dart static analysis is run separately. CI is configured for Flutter 3.41.9, analysis, tests and a release web build using placeholder public config. Check the actual CI result before deployment.
- New regression coverage: navigation specificity, saved theme, contrast/form layout at 390/834/1440, reduced-motion confirmation.
- Exact Figma SVG asset downloads returned an unavailable page in this environment. Existing native Material icons remain; exact icon fidelity is pending.
- This is a shared-theme/navigation and key-flow implementation, not verified pixel parity for every Figma frame. Authenticated browser comparison across all module bodies is still required.
- No home-server SSH credential is present in the ChatGPT environment. No deployment, SQL migration, ERP change, or financial test posting has been made by this implementation session.

## Mac continuation

1. Preserve existing local edits and untracked tmp/. Fetch origin.
2. Prefer a separate worktree from origin/feat/approved-figma-responsive-ui so .metadata/tmp in the existing checkout remain intact.
3. Use the existing private public-client config locally; never commit it. CI placeholder config is not a production deployment config.
4. Run flutter pub get, flutter analyze --no-fatal-infos, flutter test, flutter build web --release. Resolve real failures before deployment.
5. Check browser layouts and the authenticated AM_DEMO Receive/Pay/confirmation flow. Do not create real-business transactions for UI testing.
6. Restore SSH access to dinserver. Verify identity and existing accounts-manager-web mounts/port before touching deployment. Keep ERP containers and database untouched; this branch has no SQL migrations.
7. Back up the current FX web docroot, use the established deployment/cache-bust procedure with this build's SHA, preserve OCR assets, verify index/public config/OCR assets and denied private env paths, and verify the public build identity. Roll back the FX web artifact on failed health checks.

Do not report deployment complete until the public URL and build identity are verified.
