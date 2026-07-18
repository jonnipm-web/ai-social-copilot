import 'package:ai_social_copilot/features/ive/domain/ive_route_context.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('escopo do chat separa usuário, projeto e tela', () {
    const base = CopilotScope(
      userId: 'user-1',
      projectId: 'project-1',
      screenName: 'Executive Dashboard',
    );

    expect(
      base,
      const CopilotScope(
        userId: 'user-1',
        projectId: 'project-1',
        screenName: 'Executive Dashboard',
      ),
    );
    expect(
      base,
      isNot(const CopilotScope(
        userId: 'user-2',
        projectId: 'project-1',
        screenName: 'Executive Dashboard',
      )),
    );
    expect(
      base,
      isNot(const CopilotScope(
        userId: 'user-1',
        projectId: 'project-2',
        screenName: 'Executive Dashboard',
      )),
    );
  });

  test('contexto enviado contém somente o projeto ativo', () {
    const data = IveContextData(
      userId: 'user-1',
      activeProjectId: 'project-1',
      activeProjectName: 'Projeto principal',
      healthScore: 75,
      pendingActionsSummary: [
        {'id': 'action-1', 'title': 'Executar campanha'},
      ],
    );

    final context = data.toCopilotContext(route: '/executive-dashboard');

    expect(context.userId, 'user-1');
    expect(context.projectId, 'project-1');
    expect(context.project?['id'], 'project-1');
    expect(context.actions.single['id'], 'action-1');
    expect(context.toMap(), isNot(contains('projects')));
  });

  test('rota parametrizada mantém uma fonte de contexto estável', () {
    expect(
      IveRouteContext.normalize('/action-engine/action-1?tab=details'),
      '/action-engine',
    );
    expect(
      IveRouteContext.displayName('/opportunity-lab/opp-1'),
      'Opportunity Lab',
    );
    expect(IveRouteContext.displayName('/content'), 'Library');
  });
}
