//------------------------------------------------------------------------------
// Dijkstra on PyCoRAM (Software)
// Copyright (C) 2013, Shinya Takamaeda-Yamazaki
// License: Apache 2.0
//------------------------------------------------------------------------------
#include "dijkstra.h"

//------------------------------------------------------------------------------
void Dijkstra::add_node(Uint id)
{
  if(this->idtable.count(id) == 0){
    this->node_array.push_back( new Node(id) );
    this->idtable[id] = this->node_array.back();
    this->number_of_nodes++;
  }
}

void Dijkstra::add_edge(Uint src, Uint dst, Uint cost)
{
  this->add_node(src);
  this->add_node(dst);
  this->idtable[src]->add_edge(dst, cost);
  this->number_of_edges++;
}

void Dijkstra::push_heap(Uint cost, Uint id)
{
  this->heap.push( pair<Uint, Uint>(cost, id) );
}

void Dijkstra::pop_heap(Uint& cost, Uint& id)
{
  auto p = this->heap.top();
  cost = p.first;
  id = p.second;
  this->heap.pop();
}

Node* Dijkstra::get_node(Uint id)
{
  return this->idtable[id];
}

void Dijkstra::update(Uint cost, Node* node)
{
  for(auto page=node->pages.begin(); page != node->pages.end(); ++page){
    for(auto edge=(*page)->edges.begin(); edge != (*page)->edges.end(); ++edge){
      Node* next_node = get_node(edge->first);
      Uint new_cost = edge->second + cost;
      if(!next_node->visited && (next_node->current_cost == 0 || next_node->current_cost > new_cost)){
        next_node->current_cost = new_cost;
        next_node->parent_node = node;
        this->push_heap(new_cost, edge->first);
      }
    }
  }
}

void Dijkstra::find_shortest_path(Uint start, Uint goal, Uint& cost, list<Uint>& result)
{
  this->push_heap(0, start);
  Uint current = start;

  while(current != goal){
    this->pop_heap(cost, current);
    Node* current_node = get_node(current);
    if(current_node->visited) continue;
    current_node->set_visited();
    this->update(cost, current_node);
  }

  Node* pnode = get_node(goal);
  Node* start_node = get_node(start);
  while(pnode != start_node){
    result.push_back(pnode->id);
    pnode = pnode->parent_node;
  }
  result.push_back(start);
}

void Dijkstra::print_result(Uint cost, list<Uint>& result)
{
  printf("route: ");
  for(auto it=result.begin(); it!=result.end(); ++it){
    printf("%d\n", *it);
  }
  printf("\n");
  printf("cost: %d\n", cost);
}

//------------------------------------------------------------------------------
int main(int argc, char** argv)
{
  FILE* fp = fopen(argv[3], "r");
  if(fp == NULL){
    printf("no such file\n");
    return -1;
  }

  Uint start = atoi(argv[1]);
  Uint goal = atoi(argv[2]);
  Uint number_of_nodes;
  Uint number_of_edges;

  /*
  Uint start, goal;
  if(fscanf(stdin, "%d %d\n", &start, &goal) != 2){
    exit(-1);    
  }
  */

  if(fscanf(fp, "%d %d\n", &number_of_nodes, &number_of_edges) != 2){
    exit(-1);
  }

  /*
  if(fscanf(stdin, "%d %d\n", &number_of_nodes, &number_of_edges) != 2){
    exit(-1);
  }
  */

  if(number_of_nodes > MAX_NODES || number_of_edges > (MAX_PAGES * PAGE_SIZE)){
    printf("Graph size exceeds the maximum memory capacity.");
    return -1;
  }

  Dijkstra dijkstra;

  Uint from, to, cost;

  while(fscanf(fp, "%d %d %d\n", &from, &to, &cost) == 3){
    dijkstra.add_edge(from, to, cost);
    //dijkstra.add_edge(to, from, cost); // undirected graph
  }

  /*
  while(fscanf(stdin, "%d %d %d\n", &from, &to, &cost) == 3){
    dijkstra.add_edge(from, to, cost);
    //dijkstra.add_edge(to, from, cost); // undirected graph
  }
  */

  printf("start:%d goal:%d\r\n", start, goal);
  printf("num_nodes:%d num_edges:%d\r\n", number_of_nodes, number_of_edges);

  Uint sum_cost;
  list<Uint> result;

  dijkstra.find_shortest_path(start, goal, sum_cost, result);
  dijkstra.print_result(sum_cost, result);

  return 0;
}
